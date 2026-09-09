require 'rails_helper'

describe Webhooks::EvolutionGoEventsJob do
  subject(:job) { described_class.new }

  let(:channel) do
    create(
      :channel_whatsapp,
      provider: 'evolution_go',
      provider_config: { 'instance_token' => 'token', 'instance_id' => 'id' },
      sync_templates: false,
      validate_provider_config: false,
      provider_instance_callbacks: false
    )
  end

  let(:info) do
    {
      'ID' => 'wamid-1',
      'IsGroup' => true,
      'Chat' => '120363111122223333@g.us',
      'Sender' => '5511988887777@s.whatsapp.net',
      'SenderAlt' => '27041265119351@lid'
    }
  end

  let(:params) do
    { 'event' => 'Message', 'channel_id' => channel.id, 'data' => { 'Info' => info, 'Message' => { 'conversation' => 'hi' } } }
  end

  describe 'message locking' do
    let(:lock_manager) { instance_double(Redis::LockManager, lock: true, unlock: true) }

    before do
      allow(Redis::LockManager).to receive(:new).and_return(lock_manager)
      allow(Whatsapp::IncomingMessageEvolutionGoService).to receive(:new)
        .and_return(instance_double(Whatsapp::IncomingMessageEvolutionGoService, perform: nil))
    end

    it 'locks a group message on the group chat, not on the participant who spoke' do
      job.perform(params)

      expect(lock_manager).to have_received(:lock).with(a_string_including('120363111122223333@g.us'), 30.seconds)
    end

    it 'still locks a direct message on the phone jid' do
      direct_info = info.merge('IsGroup' => false, 'Chat' => '5511988887777@s.whatsapp.net')

      job.perform(params.merge('data' => { 'Info' => direct_info, 'Message' => { 'conversation' => 'hi' } }))

      expect(lock_manager).to have_received(:lock).with(a_string_including('5511988887777@s.whatsapp.net'), 30.seconds)
    end
  end
end
