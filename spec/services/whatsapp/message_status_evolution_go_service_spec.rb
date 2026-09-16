require 'rails_helper'

describe Whatsapp::MessageStatusEvolutionGoService do
  subject(:service) { described_class.new(inbox: inbox, params: params) }

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
  let(:conversation) { create(:conversation, inbox: inbox, account: inbox.account) }

  let(:params) do
    {
      'event' => 'Receipt',
      'state' => state,
      'data' => {
        'Chat' => '5511988887777@s.whatsapp.net',
        'IsFromMe' => is_from_me,
        'MessageIDs' => [message.source_id],
        'Timestamp' => 1.minute.from_now.iso8601
      }
    }
  end

  describe "'Read' receipt for our outgoing message (contact read it)" do
    let(:state) { 'Read' }
    let(:is_from_me) { true }
    let!(:message) { create(:message, conversation: conversation, message_type: :outgoing, status: :delivered, source_id: 'wamid-out-1') }

    it 'marks the outgoing message as read' do
      service.perform

      expect(message.reload.status).to eq('read')
    end
  end

  describe "'Read' receipt for the contact's own message (agent read it on their phone)" do
    let(:state) { 'Read' }
    let(:is_from_me) { false }
    let!(:message) { create(:message, conversation: conversation, message_type: :incoming, status: :sent, source_id: 'wamid-in-1') }

    it 'does not change the incoming message status' do
      service.perform

      expect(message.reload.status).to eq('sent')
    end

    it 'marks the conversation as seen by the agent' do
      expect { service.perform }.to(change { conversation.reload.agent_last_seen_at })
    end
  end
end
