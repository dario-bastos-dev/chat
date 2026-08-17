require 'rails_helper'

describe Whatsapp::IncomingMessageEvolutionGoService do
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

  let(:info) do
    {
      'ID' => 'wamid-1',
      'IsFromMe' => false,
      'IsGroup' => false,
      'Sender' => '5511988887777@s.whatsapp.net',
      'SenderAlt' => '27041265119351@lid',
      'Chat' => '5511988887777@s.whatsapp.net',
      'PushName' => 'Alex',
      'Timestamp' => '2026-04-21T20:38:16-03:00',
      'Type' => 'text'
    }
  end

  let(:params) { { 'event' => 'Message', 'data' => { 'Info' => info, 'Message' => message_body } } }
  let(:message_body) { { 'conversation' => 'hello there' } }

  describe 'text messages' do
    it 'creates the message and the contact' do
      expect { service.perform }.to change(Message, :count).by(1)

      message = inbox.messages.last
      expect(message.content).to eq('hello there')
      expect(message.source_id).to eq('wamid-1')
      expect(message.message_type).to eq('incoming')
      expect(message.conversation.contact.name).to eq('Alex')
    end

    it 'records the author jid so a later reply can quote it' do
      service.perform

      expect(inbox.messages.last.content_attributes['sender_jid']).to eq('5511988887777@s.whatsapp.net')
    end

    it 'does not create the same message twice' do
      service.perform
      described_class.new(inbox: inbox, params: params).perform

      expect(inbox.messages.where(source_id: 'wamid-1').count).to eq(1)
    end

    it 'stores the lid to phone mapping' do
      service.perform

      mapping = Channel::WhatsappLidMapping.find_by(account_id: inbox.account_id, lid: '27041265119351')
      expect(mapping.phone_number).to eq('5511988887777')
    end
  end

  describe 'messages with no renderable content' do
    context 'when it is a reaction' do
      let(:message_body) { { 'reactionMessage' => { 'text' => '👍' } } }

      it 'does not create a blank message' do
        expect { service.perform }.not_to change(Message, :count)
      end
    end

    context 'when it is a protocol frame' do
      let(:message_body) { { 'protocolMessage' => { 'type' => 5 } } }

      it 'does not create a blank message' do
        expect { service.perform }.not_to change(Message, :count)
      end
    end
  end

  describe 'interactive replies' do
    context 'when the contact taps a button' do
      let(:message_body) { { 'buttonsResponseMessage' => { 'selectedDisplayText' => 'Yes, please' } } }

      it 'stores the chosen label as the content' do
        service.perform

        expect(inbox.messages.last.content).to eq('Yes, please')
      end
    end

    context 'when the contact picks from a list' do
      let(:message_body) { { 'listResponseMessage' => { 'title' => 'Option B' } } }

      it 'stores the chosen title as the content' do
        service.perform

        expect(inbox.messages.last.content).to eq('Option B')
      end
    end
  end

  describe 'location messages' do
    let(:message_body) do
      { 'locationMessage' => { 'name' => 'Office', 'degreesLatitude' => -23.5, 'degreesLongitude' => -46.6 } }
    end

    it 'renders the coordinates as text' do
      service.perform

      expect(inbox.messages.last.content).to include('Office', 'maps.google.com')
    end
  end

  describe 'quoted messages' do
    context 'when the id only appears in contextInfo' do
      let(:message_body) do
        { 'extendedTextMessage' => { 'text' => 'replying', 'contextInfo' => { 'stanzaID' => 'quoted-id' } } }
      end

      it 'picks the id up from contextInfo' do
        service.perform

        expect(inbox.messages.last.content_attributes['in_reply_to_external_id']).to eq('quoted-id')
      end
    end
  end

  describe 'edited messages' do
    let(:other_inbox) { create(:inbox, account: create(:account)) }
    let!(:foreign_message) { create(:message, inbox: other_inbox, account: other_inbox.account, source_id: 'wamid-original') }

    let(:info) do
      super().merge('Edit' => '1')
    end
    let(:message_body) do
      {
        'protocolMessage' => {
          'key' => { 'ID' => 'wamid-original' },
          'editedMessage' => { 'conversation' => 'edited text' }
        }
      }
    end

    it 'never rewrites a message belonging to another inbox' do
      expect { service.perform }.not_to(change { foreign_message.reload.content })
    end
  end

  describe 'attachments' do
    let(:info) { super().merge('Type' => 'media', 'MediaType' => 'image') }
    let(:message_body) do
      {
        'imageMessage' => { 'mimetype' => 'image/jpeg', 'caption' => 'look' },
        'mediaUrl' => 'https://example.com/media/file.jpg',
        'mimetype' => 'image/jpeg'
      }
    end

    it 'creates the message immediately and fetches the media out of band' do
      expect { service.perform }
        .to change(Message, :count).by(1)
        .and have_enqueued_job(Webhooks::EvolutionGoMediaJob)

      expect(inbox.messages.last.content).to eq('look')
    end
  end

  # EvoGO sends either lid+phone or lid alone, never the phone by itself, so the lid is the one
  # identifier always present and is what ties the two payload shapes to the same person.
  describe 'lid then phone' do
    let(:lid_only_params) do
      {
        'event' => 'Message',
        'data' => {
          'Info' => {
            'ID' => 'wamid-lid-only',
            'IsFromMe' => false,
            'IsGroup' => false,
            'Sender' => '27041265119351@lid',
            'SenderAlt' => '',
            'Chat' => '27041265119351@lid',
            'PushName' => 'Alex',
            'Type' => 'text'
          },
          'Message' => { 'conversation' => 'first message' }
        }
      }
    end

    it 'promotes the lid contact instead of creating a second one' do
      described_class.new(inbox: inbox, params: lid_only_params).perform
      expect(Contact.count).to eq(1)

      # The follow-up carries both halves.
      service.perform

      expect(Contact.count).to eq(1)
      contact = Contact.last
      expect(contact.phone_number).to eq('+5511988887777')
      expect(contact.identifier).to eq('5511988887777@s.whatsapp.net')
      expect(inbox.contact_inboxes.pluck(:source_id)).to eq(['5511988887777'])
    end

    it 'keeps both messages on the same conversation' do
      described_class.new(inbox: inbox, params: lid_only_params).perform
      service.perform

      expect(Conversation.count).to eq(1)
      expect(inbox.messages.count).to eq(2)
    end

    context 'when a contact for that phone already exists' do
      let!(:phone_contact) do
        create(:contact, account: inbox.account, phone_number: '+5511988887777')
      end

      it 'merges the lid contact into it rather than leaving two' do
        described_class.new(inbox: inbox, params: lid_only_params).perform
        service.perform

        expect(inbox.messages.last.conversation.contact_id).to eq(phone_contact.id)
        expect(Contact.where(identifier: '27041265119351@lid')).to be_empty
      end
    end
  end

  describe 'groups and broadcasts' do
    context 'when the message comes from a group' do
      let(:info) { super().merge('IsGroup' => true) }

      it 'is ignored' do
        expect { service.perform }.not_to change(Message, :count)
      end
    end
  end
end
