require 'rails_helper'

RSpec.describe Mcp::Server do
  subject(:server) { described_class.new(runner: runner, read_only: read_only) }

  let(:runner) { instance_double(Mcp::ToolRunner) }
  let(:read_only) { false }

  def request(method, params = nil)
    { 'jsonrpc' => '2.0', 'id' => 7, 'method' => method, 'params' => params }.compact
  end

  describe 'initialize' do
    it 'answers with the protocol version the client asked for when it is supported' do
      reply = server.handle(request('initialize', 'protocolVersion' => '2025-03-26'))

      expect(reply).to include(jsonrpc: '2.0', id: 7)
      expect(reply[:result]).to include(protocolVersion: '2025-03-26', capabilities: { tools: { listChanged: false } })
      expect(reply[:result][:serverInfo][:name]).to eq('chatwoot')
    end

    it 'answers with the newest supported version otherwise' do
      reply = server.handle(request('initialize', 'protocolVersion' => '1999-01-01'))

      expect(reply[:result][:protocolVersion]).to eq('2025-06-18')
    end
  end

  describe 'messages that need no reply' do
    it 'returns nothing for notifications' do
      expect(server.handle('jsonrpc' => '2.0', 'method' => 'notifications/initialized')).to be_nil
    end

    it 'returns nothing for responses to server requests' do
      expect(server.handle('jsonrpc' => '2.0', 'id' => 1, 'result' => {})).to be_nil
    end
  end

  describe 'invalid messages' do
    it 'rejects batches and anything that is not a JSON-RPC 2.0 object' do
      expect(server.handle([request('ping')])[:error]).to include(code: Mcp::ProtocolError::INVALID_REQUEST)
      expect(server.handle('id' => 1, 'method' => 'ping')[:error]).to include(code: Mcp::ProtocolError::INVALID_REQUEST)
    end

    it 'rejects unknown methods keeping the request id' do
      reply = server.handle(request('resources/list'))

      expect(reply).to include(id: 7, error: { code: Mcp::ProtocolError::METHOD_NOT_FOUND, message: 'Method not found: resources/list' })
    end

    it 'rejects params that are not an object' do
      reply = server.handle('jsonrpc' => '2.0', 'id' => 7, 'method' => 'tools/list', 'params' => [])

      expect(reply[:error]).to include(code: Mcp::ProtocolError::INVALID_PARAMS)
    end
  end

  describe 'ping' do
    it 'answers with an empty result' do
      expect(server.handle(request('ping'))).to eq(jsonrpc: '2.0', id: 7, result: {})
    end
  end

  describe 'tools/list' do
    let(:names) { server.handle(request('tools/list'))[:result][:tools].pluck(:name) }

    it 'lists every tool' do
      expect(names).to include('list_conversations', 'send_message', 'create_label')
    end

    context 'when it is read-only' do
      let(:read_only) { true }

      it 'lists only the tools that read data' do
        expect(names).to include('list_conversations', 'get_contact')
        expect(names).not_to include('send_message', 'create_label', 'update_contact')
      end
    end
  end

  describe 'tools/call' do
    let(:result) { Mcp::ToolRunner::Result.new('{"id":1}', false) }

    it 'runs the tool with the arguments and returns its output as text' do
      allow(runner).to receive(:call).and_return(result)

      reply = server.handle(request('tools/call', 'name' => 'get_conversation', 'arguments' => { 'conversation_id' => 1 }))

      expect(runner).to have_received(:call).with(Mcp::ToolCatalog.find('get_conversation'), 'conversation_id' => 1)
      expect(reply[:result]).to eq(content: [{ type: 'text', text: '{"id":1}' }], isError: false)
    end

    it 'flags the result as an error when the endpoint failed' do
      allow(runner).to receive(:call).and_return(Mcp::ToolRunner::Result.new('{"error":"not found"}', true))

      reply = server.handle(request('tools/call', 'name' => 'get_conversation', 'arguments' => { 'conversation_id' => 1 }))

      expect(reply[:result]).to include(isError: true)
    end

    it 'reports invalid arguments as a tool error so the model can correct them' do
      allow(runner).to receive(:call).and_raise(Mcp::InvalidArguments, 'Missing required arguments: content')

      reply = server.handle(request('tools/call', 'name' => 'send_message', 'arguments' => {}))

      expect(reply[:result]).to eq(content: [{ type: 'text', text: 'Missing required arguments: content' }], isError: true)
    end

    it 'rejects tools that do not exist' do
      reply = server.handle(request('tools/call', 'name' => 'delete_contact'))

      expect(reply[:error]).to include(code: Mcp::ProtocolError::INVALID_PARAMS, message: 'Unknown tool: delete_contact')
    end

    it 'rejects arguments that are not an object' do
      reply = server.handle(request('tools/call', 'name' => 'list_labels', 'arguments' => 'x'))

      expect(reply[:error]).to include(code: Mcp::ProtocolError::INVALID_PARAMS)
    end

    context 'when it is read-only' do
      let(:read_only) { true }

      it 'refuses to run tools that change data' do
        allow(runner).to receive(:call)

        reply = server.handle(request('tools/call', 'name' => 'send_message', 'arguments' => { 'conversation_id' => 1, 'content' => 'Hi' }))

        expect(runner).not_to have_received(:call)
        expect(reply[:result]).to include(isError: true)
        expect(reply[:result][:content].first[:text]).to include('read-only')
      end
    end
  end
end
