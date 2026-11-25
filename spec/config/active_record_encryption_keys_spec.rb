require 'rails_helper'

RSpec.describe ActiveRecordEncryptionKeys do
  let(:keys_dir) { Dir.mktmpdir }
  let(:keys_path) { File.join(keys_dir, 'nested', 'active_record_encryption_keys.json') }
  let(:blank_keys) { described_class::ENV_KEYS.index_with { nil } }

  after { FileUtils.remove_entry(keys_dir) }

  def load_keys(env)
    with_modified_env(blank_keys.merge(env)) do
      described_class.load!
      described_class::ENV_KEYS.index_with { |key| ENV.fetch(key, nil) }
    end
  end

  it 'generates the keys file on first boot and exports the keys' do
    loaded = load_keys('ACTIVE_RECORD_ENCRYPTION_KEYS_FILE' => keys_path)

    expect(loaded.values).to all(match(/\A\h{64}\z/))
    expect(JSON.parse(File.read(keys_path))).to eq(loaded)
    expect(File.stat(keys_path).mode & 0o777).to eq(0o600)
    expect(Dir.glob("#{keys_path}.*.tmp")).to be_empty
  end

  it 'reuses the persisted keys on later boots' do
    first_boot = load_keys('ACTIVE_RECORD_ENCRYPTION_KEYS_FILE' => keys_path)
    second_boot = load_keys('ACTIVE_RECORD_ENCRYPTION_KEYS_FILE' => keys_path)

    expect(second_boot).to eq(first_boot)
  end

  it 'keeps the existing file when another process created it first' do
    FileUtils.mkdir_p(File.dirname(keys_path))
    existing = described_class::ENV_KEYS.index_with { |key| "existing-#{key}" }
    File.write(keys_path, existing.to_json)

    described_class.create_file(keys_path)

    expect(JSON.parse(File.read(keys_path))).to eq(existing)
    expect(Dir.glob("#{keys_path}.*.tmp")).to be_empty
  end

  it 'does nothing when the keys file is not configured' do
    loaded = load_keys('ACTIVE_RECORD_ENCRYPTION_KEYS_FILE' => nil)

    expect(loaded.values).to all(be_nil)
  end

  it 'keeps keys set explicitly in the environment' do
    loaded = load_keys(
      'ACTIVE_RECORD_ENCRYPTION_KEYS_FILE' => keys_path,
      'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'explicit-primary'
    )

    expect(loaded['ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY']).to eq('explicit-primary')
    expect(File).not_to exist(keys_path)
  end
end
