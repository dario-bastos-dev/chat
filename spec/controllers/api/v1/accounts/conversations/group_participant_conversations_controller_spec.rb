require 'rails_helper'

RSpec.describe 'Group participant conversations API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:channel) do
    create(:channel_whatsapp, account: account, provider: 'evolution_go',
                              provider_config: { 'instance_token' => 'token', 'instance_id' => 'id' },
                              sync_templates: false, validate_provider_config: false,
                              provider_instance_callbacks: false)
  end
  let(:group_contact) { create(:contact, account: account, identifier: '120363111122223333@g.us', phone_number: nil) }
  let(:group_conversation) do
    create(:conversation, account: account, inbox: channel.inbox, contact: group_contact,
                          additional_attributes: { 'group_participants' => [
                            { 'jid' => '5527998999017@s.whatsapp.net', 'phone' => '5527998999017@s.whatsapp.net', 'name' => 'Alex' }
                          ] })
  end
  let(:url) do
    api_v1_account_conversation_group_participant_conversation_url(account_id: account.id,
                                                                   conversation_id: group_conversation.display_id)
  end

  it 'returns unauthorized without a session' do
    post url, params: { participant_jid: '5527998999017@s.whatsapp.net' }, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  context 'when the agent can see the group' do
    before { create(:inbox_member, inbox: channel.inbox, user: agent) }

    it 'returns the private conversation with the member' do
      post url, params: { participant_jid: '5527998999017@s.whatsapp.net' }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      conversation = account.conversations.find_by(display_id: response.parsed_body['id'])
      expect(conversation.contact.phone_number).to eq('+5527998999017')
      expect(conversation.assignee).to eq(agent)
    end

    it 'returns not found for someone outside the group' do
      post url, params: { participant_jid: '5599911112222@s.whatsapp.net' }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  it 'refuses an agent who cannot see the group' do
    post url, params: { participant_jid: '5527998999017@s.whatsapp.net' }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
