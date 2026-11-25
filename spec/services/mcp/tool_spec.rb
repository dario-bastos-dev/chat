require 'rails_helper'

RSpec.describe Mcp::Tool do
  let(:get_conversation) { Mcp::ToolCatalog.find('get_conversation') }
  let(:update_label) { Mcp::ToolCatalog.find('update_label') }
  let(:send_message) { Mcp::ToolCatalog.find('send_message') }

  describe '#path_for' do
    it 'fills the path placeholders with the numeric arguments' do
      expect(send_message.path_for('conversation_id' => 12, 'content' => 'Hi')).to eq('conversations/12/messages')
    end

    it 'accepts ids sent as numeric strings' do
      expect(get_conversation.path_for('conversation_id' => '12')).to eq('conversations/12')
    end

    it 'rejects ids that could change the endpoint being called' do
      expect { get_conversation.path_for('conversation_id' => '1/../labels') }
        .to raise_error(Mcp::InvalidArguments, 'Arguments must be numeric ids: conversation_id')
    end

    it 'rejects missing required arguments' do
      expect { send_message.path_for('conversation_id' => 12) }
        .to raise_error(Mcp::InvalidArguments, 'Missing required arguments: content')
    end

    it 'rejects arguments the tool does not declare' do
      expect { get_conversation.path_for('conversation_id' => 12, 'account_id' => 2) }
        .to raise_error(Mcp::InvalidArguments, 'Unknown arguments: account_id')
    end
  end

  describe '#request_arguments' do
    it 'leaves out the arguments that are already in the path' do
      expect(send_message.request_arguments('conversation_id' => 12, 'content' => 'Hi')).to eq('content' => 'Hi')
    end

    it 'nests the arguments under the body key of the endpoint' do
      expect(update_label.request_arguments('label_id' => 3, 'color' => '#fff')).to eq('label' => { 'color' => '#fff' })
    end
  end

  describe '#definition' do
    def annotations_of(name)
      Mcp::ToolCatalog.find(name).definition[:annotations]
    end

    it 'describes the arguments as a JSON Schema' do
      expect(get_conversation.definition[:inputSchema]).to include(type: 'object', required: ['conversation_id'])
    end

    it 'marks reading tools as read-only and harmless' do
      expect(annotations_of('get_conversation')).to eq(readOnlyHint: true, destructiveHint: false, openWorldHint: false)
    end

    it 'marks tools that overwrite existing data as destructive so clients can ask for confirmation' do
      %w[update_contact update_label set_contact_labels set_conversation_labels set_conversation_status assign_conversation
         set_conversation_priority set_conversation_custom_attributes].each do |name|
        expect(annotations_of(name)).to include(readOnlyHint: false, destructiveHint: true)
      end
    end

    it 'marks tools that only add data as not destructive' do
      %w[create_contact create_conversation create_label send_message].each do |name|
        expect(annotations_of(name)).to include(readOnlyHint: false, destructiveHint: false)
      end
    end

    it 'marks tools that reach the customer outside of Chatwoot as open world' do
      expect(annotations_of('send_message')).to include(openWorldHint: true)
      expect(annotations_of('create_conversation')).to include(openWorldHint: true)
      expect(annotations_of('update_contact')).to include(openWorldHint: false)
    end
  end

  describe 'catalog' do
    it 'only has tools that read, create or update data' do
      expect(Mcp::ToolCatalog.tools.map(&:http_method).uniq).to contain_exactly('GET', 'POST', 'PATCH')
    end

    it 'declares every path placeholder as a required argument' do
      Mcp::ToolCatalog.tools.each do |tool|
        placeholders = tool.path.scan(Mcp::Tool::PATH_PARAMETER).flatten
        expect(placeholders - tool.definition[:inputSchema].fetch(:required, [])).to be_empty
      end
    end
  end
end
