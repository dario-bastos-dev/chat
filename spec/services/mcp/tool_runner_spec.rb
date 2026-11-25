require 'rails_helper'

RSpec.describe Mcp::ToolRunner do
  subject(:runner) { described_class.new(request: ActionDispatch::TestRequest.create, account_id: 1) }

  let(:tool) { Mcp::ToolCatalog.find('list_labels') }

  def run_with_response(status, body)
    allow(Rails.application).to receive(:call).and_return([status, {}, [body]])
    runner.call(tool, {})
  end

  it 'returns the body of a successful response as it is' do
    result = run_with_response(200, '{"payload":[]}')

    expect(result).to have_attributes(text: '{"payload":[]}', error: false)
  end

  it 'says OK when a successful response has no body' do
    expect(run_with_response(200, '')).to have_attributes(text: 'OK', error: false)
    expect(run_with_response(204, '')).to have_attributes(text: 'OK', error: false)
  end

  it 'flags client and server errors and keeps what the API said' do
    not_found = '{"error":"Resource could not be found"}'

    expect(run_with_response(404, not_found)).to have_attributes(text: not_found, error: true)
    expect(run_with_response(500, 'boom')).to have_attributes(text: 'boom', error: true)
  end

  it 'flags redirects as failures instead of reporting an empty success' do
    expect(run_with_response(301, '')).to have_attributes(text: 'The request failed with status 301', error: true)
  end

  it 'explains an error response that has no body' do
    expect(run_with_response(401, '')).to have_attributes(text: 'The request failed with status 401', error: true)
  end
end
