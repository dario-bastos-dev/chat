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
    it 'describes the arguments as a JSON Schema and marks reading tools as read-only' do
      definition = get_conversation.definition

      expect(definition[:inputSchema]).to include(type: 'object', required: ['conversation_id'])
      expect(definition[:annotations]).to eq(readOnlyHint: true, destructiveHint: false)
      expect(send_message.definition[:annotations][:readOnlyHint]).to be(false)
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
