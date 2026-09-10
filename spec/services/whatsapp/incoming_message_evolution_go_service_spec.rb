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

    it 'stores the pin as a location attachment' do
      service.perform

      attachment = inbox.messages.last.attachments.last
      expect(attachment.file_type).to eq('location')
      expect(attachment.coordinates_lat).to eq(-23.5)
      expect(attachment.coordinates_long).to eq(-46.6)
      expect(attachment.fallback_title).to eq('Office')
    end
  end

  describe 'quoted messages' do
    context 'when the id only appears in contextInfo' do
      let(:message_body) do
        { 'extendedTextMessage' => { 'text' => 'replying', 'contextInfo' => { 'stanzaID' => 'quoted-id' } } }
      end

      it 'picks the id up from contextInfo' do
        # Messages::InReplyToMessageBuilder resolves the external id against the conversation and
        # drops it when nothing matches, so the quoted message has to be there first.
        described_class.new(
          inbox: inbox,
          params: { 'event' => 'Message',
                    'data' => { 'Info' => info.merge('ID' => 'quoted-id'),
                                'Message' => { 'conversation' => 'the original' } } }
        ).perform

        service.perform

        # Both messages carry the payload timestamp and Message is ordered by created_at, so the
        # reply has to be addressed by its own id rather than by position.
        reply = inbox.messages.find_by(source_id: 'wamid-1')
        expect(reply.content_attributes['in_reply_to_external_id']).to eq('quoted-id')
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
    # Unique id per example: the dedup lock lives in a pooled MockRedis that is not reset between
    # examples, so a shared source_id can make a later perform a no-op.
    let(:info) { super().merge('Type' => 'media', 'MediaType' => 'image', 'ID' => "wamid-media-#{SecureRandom.hex(4)}") }
    let(:message_body) do
      {
        'imageMessage' => { 'mimetype' => 'image/jpeg', 'caption' => 'look' },
        'mediaUrl' => 'https://example.com/media/file.jpg',
        'mimetype' => 'image/jpeg'
      }
    end

    let(:downloaded_tempfile) do
      file = Tempfile.new(['evolution-go-media', '.jpg'])
      file.binmode
      file.write('FAKE_IMAGE_BYTES')
      file.rewind
      file
    end

    # SafeFetch closes and unlinks its tempfile as soon as the block returns, so the stub does the
    # same. An implementation that only reads the io later (at save! time) has to fail here exactly
    # as it does in production.
    before do
      allow(SafeFetch).to receive(:fetch)
        .with('https://example.com/media/file.jpg', validate_content_type: false, allow_private_network: true) do |_url, **_opts, &block|
          block.call(SafeFetch::Result.new(tempfile: downloaded_tempfile, filename: 'file.jpg', content_type: 'image/jpeg'))
        ensure
          downloaded_tempfile.close!
        end
    end

    it 'downloads the media and creates the message with the attachment' do
      expect { service.perform }.to change(Message, :count).by(1)

      message = inbox.messages.last
      expect(message.content).to eq('look')
      expect(message.attachments.count).to eq(1)
      expect(message.attachments.first.file_type).to eq('image')
      expect(message.attachments.first.file.download).to eq('FAKE_IMAGE_BYTES')
    end

    it 'sends the attachment in the message_created payload to the bot' do
      create(:agent_bot_inbox, inbox: inbox, agent_bot: create(:agent_bot, outgoing_url: 'http://bot.test/hook'))

      payloads = []
      allow(AgentBots::WebhookJob).to receive(:perform_later) { |_url, payload, *_rest, **_opts| payloads << payload }

      service.perform

      created = payloads.find { |payload| payload[:event] == 'message_created' }
      expect(created).to be_present
      expect(created[:attachments]).to be_present
      expect(created[:attachments].first[:file_type]).to eq('image')
    end

    it 'still creates the message when the download fails but a caption is present' do
      allow(SafeFetch).to receive(:fetch).and_raise(SafeFetch::FetchError, 'boom')

      expect { service.perform }.to change(Message, :count).by(1)

      message = inbox.messages.last
      expect(message.content).to eq('look')
      expect(message.attachments).to be_empty
    end

    context 'when the download fails and there is no caption' do
      let(:message_body) do
        { 'imageMessage' => { 'mimetype' => 'image/jpeg' }, 'mediaUrl' => 'https://example.com/media/file.jpg' }
      end

      it 'raises so the dedup lock is dropped and the fetch is retried' do
        allow(SafeFetch).to receive(:fetch).and_raise(SafeFetch::FetchError, 'boom')

        expect { service.perform }.to raise_error(SafeFetch::FetchError)
        expect(Message.count).to eq(0)
      end
    end

    context 'when the payload carries inline base64' do
      let(:message_body) do
        {
          'imageMessage' => { 'mimetype' => 'image/jpeg', 'caption' => 'look' },
          'base64' => Base64.encode64('FAKE_IMAGE_BYTES'),
          'mimetype' => 'image/jpeg'
        }
      end

      it 'attaches the decoded file without hitting the network' do
        expect(SafeFetch).not_to receive(:fetch)

        expect { service.perform }.to change(Message, :count).by(1)
        expect(inbox.messages.last.attachments.count).to eq(1)
      end
    end

    context 'when EVOLUTIONGO_MEDIA_HOSTS does not include the media host' do
      around do |example|
        with_modified_env(EVOLUTIONGO_MEDIA_HOSTS: 'minio.internal,cdn.evogo.test') { example.run }
      end

      it 'skips the download and keeps the caption-only message' do
        expect(SafeFetch).not_to receive(:fetch)

        expect { service.perform }.to change(Message, :count).by(1)

        message = inbox.messages.last
        expect(message.content).to eq('look')
        expect(message.attachments).to be_empty
      end

      context 'and the message has no caption' do
        let(:message_body) do
          { 'imageMessage' => { 'mimetype' => 'image/jpeg' }, 'mediaUrl' => 'https://example.com/media/file.jpg' }
        end

        it 'does not persist a blank bubble' do
          expect { service.perform }.not_to change(Message, :count)
        end
      end
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

  # On an outgoing echo Sender holds the business's own @lid and the contact is named by Chat,
  # so anything scanning both directions at once resolves to the wrong person.
  describe 'outgoing echoes' do
    let(:params) do
      {
        'event' => 'Message',
        'data' => {
          'Info' => {
            'ID' => 'wamid-from-me',
            'IsFromMe' => true,
            'IsGroup' => false,
            'Chat' => '27041265119351@lid',
            'Sender' => '246085134118923@lid',
            'SenderAlt' => '',
            'RecipientAlt' => '5511988887777@s.whatsapp.net',
            'PushName' => 'Business',
            'Type' => 'text'
          },
          'Message' => { 'conversation' => 'sent from the phone' }
        }
      }
    end

    let!(:owner_contact_inbox) do
      # A contact_inbox keyed by the business's own lid: the lookup must not land on it.
      contact = create(:contact, account: inbox.account, identifier: '246085134118923@lid')
      create(:contact_inbox, inbox: inbox, contact: contact, source_id: '246085134118923')
    end

    it 'attributes the message to the recipient, not to the owner lid' do
      service.perform

      message = inbox.messages.last
      expect(message.message_type).to eq('outgoing')
      expect(message.conversation.contact_id).not_to eq(owner_contact_inbox.contact_id)
      expect(message.conversation.contact.phone_number).to eq('+5511988887777')
    end

    it 'maps the contact lid from Chat, not the owner lid from Sender' do
      service.perform

      expect(Channel::WhatsappLidMapping.find_by(account_id: inbox.account_id, lid: '246085134118923')).to be_nil
      expect(Channel::WhatsappLidMapping.find_by(account_id: inbox.account_id, lid: '27041265119351')).to be_present
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

  describe 'group conversations' do
    let(:group_jid) { '120363111122223333@g.us' }
    # Unique id per example: the dedup lock lives in a pooled MockRedis that is not reset between
    # examples, so a shared source_id can make a later perform a no-op.
    let(:info) do
      super().merge(
        'ID' => "wamid-group-#{SecureRandom.hex(4)}",
        'IsGroup' => true,
        'Chat' => group_jid,
        'Sender' => '5511988887777@s.whatsapp.net',
        'SenderAlt' => '27041265119351@lid',
        'PushName' => 'Alex'
      )
    end

    context 'when the channel has groups enabled' do
      let(:channel) do
        create(
          :channel_whatsapp,
          provider: 'evolution_go',
          provider_config: { 'instance_token' => 'token', 'instance_id' => 'id', 'groups_enabled' => true },
          sync_templates: false,
          validate_provider_config: false,
          provider_instance_callbacks: false
        )
      end

      it 'addresses the conversation by the group, not by the participant' do
        expect { service.perform }.to change(Message, :count).by(1)

        contact_inbox = inbox.messages.last.conversation.contact_inbox
        expect(contact_inbox.source_id).to eq(group_jid)
        expect(contact_inbox.contact.identifier).to eq(group_jid)
        expect(contact_inbox.contact.phone_number).to be_nil
      end

      it 'names the group contact instead of falling back to a random name' do
        service.perform

        expect(inbox.messages.last.conversation.contact.name).to eq('WhatsApp group (223333)')
      end

      it 'records who sent the message inside the group' do
        service.perform

        participant = inbox.messages.last.content_attributes['group_participant']
        expect(participant['name']).to eq('Alex')
        expect(participant['phone']).to eq('+5511988887777')
        expect(participant['jid']).to eq('5511988887777@s.whatsapp.net')
      end

      it 'credits the message to the participant so a later reply quotes the right person' do
        service.perform

        expect(inbox.messages.last.content_attributes['sender_jid']).to eq('5511988887777@s.whatsapp.net')
      end

      it 'keeps messages from different participants on the same conversation' do
        service.perform
        other_info = info.merge(
          'ID' => "wamid-group-#{SecureRandom.hex(4)}",
          'Sender' => '5511977776666@s.whatsapp.net',
          'SenderAlt' => '',
          'PushName' => 'Bruna'
        )
        described_class.new(
          inbox: inbox, params: { 'event' => 'Message', 'data' => { 'Info' => other_info, 'Message' => message_body } }
        ).perform

        expect(inbox.conversations.count).to eq(1)
        expect(inbox.messages.count).to eq(2)
      end

      it 'keeps the echo of a reply sent from the phone on the same group conversation' do
        service.perform
        echo_info = info.merge(
          'ID' => "wamid-group-#{SecureRandom.hex(4)}",
          'IsFromMe' => true,
          'Sender' => '5599999999999@s.whatsapp.net'
        )
        described_class.new(
          inbox: inbox, params: { 'event' => 'Message', 'data' => { 'Info' => echo_info, 'Message' => message_body } }
        ).perform

        expect(inbox.conversations.count).to eq(1)
        expect(inbox.messages.where(message_type: :outgoing).count).to eq(1)
      end

      it 'does not map the participant lid onto the group contact' do
        expect { service.perform }.not_to change(Channel::WhatsappLidMapping, :count)
      end
    end

    context 'when the payload carries the group data' do
      let(:channel) do
        create(
          :channel_whatsapp,
          provider: 'evolution_go',
          provider_config: { 'instance_token' => 'token', 'instance_id' => 'id', 'groups_enabled' => true },
          sync_templates: false,
          validate_provider_config: false,
          provider_instance_callbacks: false
        )
      end
      let(:params) do
        { 'event' => 'Message',
          'data' => { 'Info' => info, 'Message' => message_body,
                      'groupData' => { 'JID' => group_jid, 'Name' => 'Obra ABC', 'ParticipantCount' => 2 } } }
      end

      it 'names the group after its subject instead of the jid' do
        service.perform

        expect(inbox.messages.last.conversation.contact.name).to eq('Obra ABC')
      end

      it 'does not ask the API for something the payload already said' do
        service.perform

        expect(WebMock).not_to have_requested(:post, %r{/group/info})
      end

      it 'adopts the real name on a group that had only the provisional one' do
        service.perform
        group_contact = inbox.messages.last.conversation.contact
        group_contact.update!(name: 'WhatsApp group (223333)')

        described_class.new(
          inbox: inbox,
          params: params.deep_merge('data' => { 'Info' => info.merge('ID' => 'wamid-later') })
        ).perform

        expect(group_contact.reload.name).to eq('Obra ABC')
      end

      it 'leaves a name the agent chose alone' do
        service.perform
        group_contact = inbox.messages.last.conversation.contact
        group_contact.update!(name: 'Obra ABC - engenharia')

        described_class.new(
          inbox: inbox,
          params: params.deep_merge('data' => { 'Info' => info.merge('ID' => 'wamid-later') })
        ).perform

        expect(group_contact.reload.name).to eq('Obra ABC - engenharia')
      end
    end

    context 'when the payload does not carry the group data' do
      let(:channel) do
        create(
          :channel_whatsapp,
          provider: 'evolution_go',
          provider_config: { 'instance_token' => 'token', 'instance_id' => 'id', 'groups_enabled' => true },
          sync_templates: false,
          validate_provider_config: false,
          provider_instance_callbacks: false
        )
      end

      before do
        create(:installation_config, name: 'EVOLUTIONGO_API_URL', value: 'https://evogo.test')
        create(:installation_config, name: 'EVOLUTIONGO_API_TOKEN', value: 'global-token')
        GlobalConfig.clear_cache
        stub_request(:post, 'https://evogo.test/group/info')
          .to_return(status: 200, body: [{ data: { Name: 'Obra ABC' }, message: 'success' }].to_json,
                     headers: { 'Content-Type' => 'application/json' })
      end

      it 'asks the API for the subject' do
        service.perform

        expect(inbox.messages.last.conversation.contact.name).to eq('Obra ABC')
      end
    end

    context 'when the channel does not have groups enabled' do
      it 'ignores the message' do
        expect { service.perform }.not_to change(Message, :count)
      end
    end
  end
end
