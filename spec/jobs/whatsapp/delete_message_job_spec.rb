require 'rails_helper'

describe Whatsapp::DeleteMessageJob do
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
  let(:inbox) { channel.inbox }
  let(:provider) { instance_double(Whatsapp::Providers::EvolutionGoService, delete_message: true) }

  before { allow(Whatsapp::Providers::EvolutionGoService).to receive(:new).and_return(provider) }

  context 'when the conversation is a whatsapp group' do
    let(:contact) { create(:contact, account: channel.account, identifier: '120363111122223333@g.us', phone_number: nil) }
    let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: '120363111122223333@g.us') }
    let(:conversation) { create(:conversation, contact: contact, contact_inbox: contact_inbox, inbox: inbox, account: channel.account) }
    let(:message) do
      create(:message, conversation: conversation, inbox: inbox, message_type: :outgoing, source_id: 'wamid-1')
    end

    it 'deletes it on the group chat instead of giving up for want of a phone number' do
      described_class.perform_now(message.id)

      expect(provider).to have_received(:delete_message).with('120363111122223333@g.us', 'wamid-1')
    end
  end

  context 'when the conversation is with a person' do
    let(:contact) { create(:contact, account: channel.account, phone_number: '+5511988887777') }
    let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5511988887777') }
    let(:conversation) { create(:conversation, contact: contact, contact_inbox: contact_inbox, inbox: inbox, account: channel.account) }
    let(:message) do
      create(:message, conversation: conversation, inbox: inbox, message_type: :outgoing, source_id: 'wamid-2')
    end

    it 'still deletes it on their chat' do
      described_class.perform_now(message.id)

      expect(provider).to have_received(:delete_message).with('5511988887777', 'wamid-2')
    end
  end
end
