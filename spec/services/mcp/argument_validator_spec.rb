require 'rails_helper'

RSpec.describe Mcp::ArgumentValidator do
  subject(:validator) { described_class.new(parameters: parameters, required: %w[content]) }

  let(:parameters) do
    {
      'content' => { 'type' => 'string' },
      'status' => { 'type' => 'string', 'enum' => %w[open resolved] },
      'page' => { 'type' => 'integer', 'minimum' => 1 },
      'private' => { 'type' => 'boolean' },
      'labels' => { 'type' => 'array', 'items' => { 'type' => 'string' } },
      'custom_attributes' => { 'type' => 'object' }
    }
  end

  it 'has no errors for arguments that match the schema' do
    arguments = { 'content' => 'Hi', 'status' => 'open', 'page' => 2, 'private' => false, 'labels' => %w[vip], 'custom_attributes' => { 'a' => 1 } }

    expect(validator.errors(arguments)).to be_empty
  end

  it 'rejects values outside the enum and lists the accepted ones' do
    expect(validator.errors('content' => 'Hi', 'status' => 'bogus')).to eq(['status must be one of: open, resolved'])
  end

  describe 'integers' do
    it 'accepts integers and numeric strings' do
      expect(validator.errors('content' => 'Hi', 'page' => 3)).to be_empty
      expect(validator.errors('content' => 'Hi', 'page' => '3')).to be_empty
    end

    it 'rejects anything else' do
      ['abc', 5.5, true, '3x', [3]].each do |value|
        expect(validator.errors('content' => 'Hi', 'page' => value)).to eq(['page must be an integer'])
      end
    end

    it 'rejects numbers below the minimum' do
      expect(validator.errors('content' => 'Hi', 'page' => 0)).to eq(['page must be at least 1'])
      expect(validator.errors('content' => 'Hi', 'page' => '0')).to eq(['page must be at least 1'])
    end
  end

  it 'rejects values of the wrong type' do
    expect(validator.errors('content' => 5)).to eq(['content must be a string'])
    expect(validator.errors('content' => 'Hi', 'private' => 'yes')).to eq(['private must be a boolean'])
    expect(validator.errors('content' => 'Hi', 'labels' => 'vip')).to eq(['labels must be an array'])
    expect(validator.errors('content' => 'Hi', 'custom_attributes' => 'x')).to eq(['custom_attributes must be an object'])
  end

  it 'checks the items of arrays' do
    expect(validator.errors('content' => 'Hi', 'labels' => ['vip', 3])).to eq(['labels must be an array of strings'])
  end

  describe 'null' do
    it 'is accepted for optional arguments so they can be cleared' do
      expect(validator.errors('content' => 'Hi', 'status' => nil, 'page' => nil)).to be_empty
    end

    it 'is rejected for required arguments' do
      expect(validator.errors('content' => nil)).to eq(['content must not be null'])
    end
  end

  it 'reports every problem in the order the arguments were sent' do
    errors = validator.errors('status' => 'bogus', 'content' => 5, 'page' => 0)

    expect(errors).to eq(['status must be one of: open, resolved', 'content must be a string', 'page must be at least 1'])
  end
end
