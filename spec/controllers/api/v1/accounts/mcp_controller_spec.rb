require 'rails_helper'

RSpec.describe 'MCP API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/mcp" }
  let(:reply) { response.parsed_body }

  def set_config(name, value)
    InstallationConfig.find_or_initialize_by(name: name).update!(value: value)
  end

  def rpc(method, params = nil, user: admin)
    post url, headers: user.create_new_auth_token, params: { jsonrpc: '2.0', id: 1, method: method, params: params }.compact, as: :json
  end

  def call_tool(name, arguments = {}, user: admin)
    rpc('tools/call', { name: name, arguments: arguments }, user: user)
  end

  def tool_text
    reply.dig('result', 'content', 0, 'text')
  end

  def tool_json
    JSON.parse(tool_text)
  end

  describe 'when the MCP server is turned off' do
    it 'does not reveal the endpoint to unauthenticated callers' do
      post url, params: { jsonrpc: '2.0', id: 1, method: 'ping' }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns not found to authenticated callers' do
      rpc('ping')

      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found when the setting is explicitly false' do
      set_config('MCP_SERVER_ENABLED', false)
      rpc('ping')

      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when the MCP server is turned on' do
    before do
      set_config('MCP_SERVER_ENABLED', true)
      set_config('MCP_SERVER_READ_ONLY', false)
    end

    describe 'authentication' do
      it 'rejects users that do not belong to the account' do
        outsider = create(:user, account: create(:account), role: :administrator)
        rpc('ping', user: outsider)

        expect(response).to have_http_status(:unauthorized)
      end

      it 'rejects bot tokens' do
        agent_bot = create(:agent_bot, account: account)
        post url, headers: { api_access_token: agent_bot.access_token.token }, params: { jsonrpc: '2.0', id: 1, method: 'ping' }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'accepts the personal access token of a user and uses it to call the tools' do
        create(:label, account: account, title: 'vip')
        post url, headers: { api_access_token: admin.access_token.token },
                  params: { jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name: 'list_labels', arguments: {} } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(reply.dig('result', 'isError')).to be(false)
        expect(tool_text).to include('vip')
      end

      it 'accepts a Bearer access token' do
        post url, headers: { Authorization: "Bearer #{admin.access_token.token}" },
                  params: { jsonrpc: '2.0', id: 1, method: 'ping' }, as: :json

        expect(response).to have_http_status(:ok)
      end
    end

    describe 'transport' do
      it 'only accepts POST' do
        get url, headers: admin.create_new_auth_token

        expect(response).to have_http_status(:method_not_allowed)
        expect(response.headers['Allow']).to eq('POST')
      end

      it 'accepts notifications without a body in the reply' do
        post url, headers: admin.create_new_auth_token, params: { jsonrpc: '2.0', method: 'notifications/initialized' }, as: :json

        expect(response).to have_http_status(:accepted)
        expect(response.body).to be_blank
      end

      it 'answers malformed JSON with a parse error' do
        post url, headers: admin.create_new_auth_token.merge('Content-Type' => 'text/plain'), params: '{not json'

        expect(response).to have_http_status(:bad_request)
        expect(reply['error']).to include('code' => Mcp::ProtocolError::PARSE_ERROR)
      end

      it 'answers initialize with the server capabilities' do
        rpc('initialize', { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'spec', version: '1' } })

        expect(response).to have_http_status(:ok)
        expect(reply['id']).to eq(1)
        expect(reply['result']).to include('protocolVersion' => '2025-06-18', 'capabilities' => { 'tools' => { 'listChanged' => false } })
      end
    end

    describe 'tools/list' do
      it 'lists the reading and writing tools' do
        rpc('tools/list')

        names = reply.dig('result', 'tools').pluck('name')
        expect(names).to include('list_conversations', 'send_message', 'create_label')
        expect(names).not_to include(a_string_matching(/delete/))
      end

      it 'lists only the reading tools in read-only mode' do
        set_config('MCP_SERVER_READ_ONLY', true)
        rpc('tools/list')

        tools = reply.dig('result', 'tools')
        expect(tools.pluck('name')).to include('list_conversations')
        expect(tools.map { |tool| tool.dig('annotations', 'readOnlyHint') }.uniq).to eq([true])
      end

      it 'stays read-only when the setting was never saved' do
        InstallationConfig.where(name: 'MCP_SERVER_READ_ONLY').destroy_all
        rpc('tools/list')

        expect(reply.dig('result', 'tools').pluck('name')).not_to include('send_message')
      end
    end

    describe 'tools/call reading data' do
      let(:inbox) { create(:inbox, account: account) }
      let(:contact) { create(:contact, account: account, name: 'Maria Souza', email: 'maria@example.com') }
      let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
      let!(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }

      it 'lists the inboxes of the account' do
        call_tool('list_inboxes')

        expect(reply.dig('result', 'isError')).to be(false)
        expect(tool_json['payload'].pluck('id')).to include(inbox.id)
      end

      it 'finds contacts by search text' do
        call_tool('search_contacts', { q: 'maria' })

        expect(tool_json['payload'].pluck('email')).to eq(['maria@example.com'])
      end

      it 'gets a conversation by its display id' do
        call_tool('get_conversation', { conversation_id: conversation.display_id })

        expect(tool_json['id']).to eq(conversation.display_id)
      end

      it 'filters conversations with query arguments' do
        resolved = create(:conversation, account: account, inbox: inbox, status: :resolved)
        call_tool('list_conversations', { status: 'resolved', inbox_id: inbox.id })

        ids = tool_json.dig('data', 'payload').pluck('id')
        expect(ids).to eq([resolved.display_id])
      end

      it 'lists the messages of a conversation' do
        create(:message, account: account, inbox: inbox, conversation: conversation, content: 'Hello there')
        call_tool('list_messages', { conversation_id: conversation.display_id })

        expect(tool_json['payload'].pluck('content')).to include('Hello there')
      end

      it 'returns the API error as a tool error for conversations of other accounts' do
        other_account = create(:account)
        other_conversation = create_list(:conversation, 3, account: other_account).last
        call_tool('get_conversation', { conversation_id: other_conversation.display_id })

        expect(response).to have_http_status(:ok)
        expect(reply.dig('result', 'isError')).to be(true)
      end

      it 'does not call the API when an id could change the endpoint' do
        call_tool('get_conversation', { conversation_id: '1/../../labels' })

        expect(reply.dig('result', 'isError')).to be(true)
        expect(tool_text).to eq('Arguments must be numeric ids: conversation_id')
      end

      it 'does not return the conversations of inboxes an agent cannot access' do
        call_tool('get_conversation', { conversation_id: conversation.display_id }, user: agent)

        expect(reply.dig('result', 'isError')).to be(true)
      end
    end

    describe 'tools/call changing data' do
      let(:inbox) { create(:inbox, account: account) }
      let!(:conversation) { create(:conversation, account: account, inbox: inbox) }

      it 'creates a label' do
        call_tool('create_label', { title: 'vip', color: '#ff0000' })

        expect(reply.dig('result', 'isError')).to be(false)
        expect(account.labels.find_by(title: 'vip')).to have_attributes(color: '#ff0000', created_by_id: admin.id)
      end

      it 'updates a contact' do
        contact = create(:contact, account: account, name: 'Old name')
        call_tool('update_contact', { contact_id: contact.id, name: 'New name', custom_attributes: { plan: 'gold' } })

        expect(contact.reload).to have_attributes(name: 'New name', custom_attributes: { 'plan' => 'gold' })
      end

      it 'creates a contact' do
        call_tool('create_contact', { name: 'Ana', email: 'ana@example.com' })

        expect(account.contacts.from_email('ana@example.com')&.name).to eq('Ana')
      end

      it 'sends a message as the user of the token' do
        call_tool('send_message', { conversation_id: conversation.display_id, content: 'On our way' })

        message = conversation.messages.last
        expect(message).to have_attributes(content: 'On our way', message_type: 'outgoing', sender: admin, private: false)
      end

      it 'adds a private note' do
        call_tool('send_message', { conversation_id: conversation.display_id, content: 'Check billing', private: true })

        expect(conversation.messages.last).to have_attributes(content: 'Check billing', private: true)
      end

      it 'changes the status of a conversation' do
        call_tool('set_conversation_status', { conversation_id: conversation.display_id, status: 'resolved' })

        expect(conversation.reload).to be_resolved
      end

      it 'assigns a conversation to an agent' do
        create(:inbox_member, inbox: inbox, user: agent)
        call_tool('assign_conversation', { conversation_id: conversation.display_id, assignee_id: agent.id })

        expect(conversation.reload.assignee).to eq(agent)
      end

      it 'replaces the labels of a conversation' do
        call_tool('set_conversation_labels', { conversation_id: conversation.display_id, labels: %w[vip urgent] })

        expect(conversation.reload.label_list).to match_array(%w[vip urgent])
      end

      it 'sets custom attributes on a conversation' do
        call_tool('set_conversation_custom_attributes', { conversation_id: conversation.display_id, custom_attributes: { order: '42' } })

        expect(conversation.reload.custom_attributes).to include('order' => '42')
      end

      it 'keeps the permissions of the user of the token' do
        label = create(:label, account: account, title: 'billing')
        call_tool('update_label', { label_id: label.id, title: 'renamed' }, user: agent)

        expect(reply.dig('result', 'isError')).to be(true)
        expect(label.reload.title).to eq('billing')
      end

      it 'reports validation errors from the API' do
        call_tool('create_label', { title: 'has spaces' })

        expect(reply.dig('result', 'isError')).to be(true)
        expect(account.labels.find_by(title: 'has spaces')).to be_nil
      end

      context 'when the MCP server is read-only' do
        before { set_config('MCP_SERVER_READ_ONLY', true) }

        it 'does not change anything' do
          call_tool('create_label', { title: 'vip' })

          expect(reply.dig('result', 'isError')).to be(true)
          expect(tool_text).to include('read-only')
          expect(account.labels.find_by(title: 'vip')).to be_nil
        end

        it 'still reads data' do
          call_tool('list_labels')

          expect(reply.dig('result', 'isError')).to be(false)
        end
      end
    end
  end
end
