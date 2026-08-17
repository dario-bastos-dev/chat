require 'rails_helper'

describe Channel::Whatsapp do
  let(:channel) do
    create(
      :channel_whatsapp,
      provider: 'evolution_go',
      provider_config: { 'instance_token' => 'live-token', 'instance_id' => 'live-id', 'connected' => true },
      sync_templates: false,
      validate_provider_config: false,
      provider_instance_callbacks: false
    )
  end

  describe '#merge_provider_config!' do
    it 'touches only the given keys' do
      channel.merge_provider_config!('connection_status' => 'close')

      config = channel.reload.provider_config
      expect(config['connection_status']).to eq('close')
      expect(config['instance_token']).to eq('live-token')
    end

    it 'removes the requested keys' do
      channel.merge_provider_config!({ 'connected' => false }, remove: ['instance_id'])

      expect(channel.reload.provider_config).not_to have_key('instance_id')
      expect(channel.provider_config['instance_token']).to eq('live-token')
    end

    it 'does not clobber a write made by another worker' do
      other = Channel::Whatsapp.find(channel.id)
      other.merge_provider_config!('business_name' => 'Acme')

      channel.merge_provider_config!('connection_status' => 'open')

      expect(channel.reload.provider_config['business_name']).to eq('Acme')
    end
  end

  describe 'provider_config protection on update' do
    it 'keeps the stored credentials when the client sends only the toggles' do
      channel.update!(provider_config: { 'always_online' => true })

      config = channel.reload.provider_config
      expect(config['always_online']).to be(true)
      expect(config['instance_token']).to eq('live-token')
      expect(config['instance_id']).to eq('live-id')
    end

    it 'ignores a stale token echoed back by the client' do
      channel.update!(provider_config: { 'instance_token' => 'stale-token', 'read_messages' => true })

      expect(channel.reload.provider_config['instance_token']).to eq('live-token')
    end

    it 'preserves connection state the client never saw' do
      channel.merge_provider_config!('business_name' => 'Acme')

      channel.reload.update!(provider_config: { 'always_online' => true })

      expect(channel.reload.provider_config['business_name']).to eq('Acme')
    end
  end
end
