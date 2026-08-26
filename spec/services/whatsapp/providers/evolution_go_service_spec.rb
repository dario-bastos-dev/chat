require 'rails_helper'

describe Whatsapp::Providers::EvolutionGoService do
  subject(:service) { described_class.new(whatsapp_channel: channel) }

  let(:channel) do
    create(
      :channel_whatsapp,
      provider: 'evolution_go',
      provider_config: { 'instance_token' => 'instance-token', 'instance_id' => 'instance-id' },
      sync_templates: false,
      validate_provider_config: false,
      provider_instance_callbacks: false
    )
  end
  let(:conversation) { create(:conversation, inbox: channel.inbox) }
  let(:message) do
    create(:message, conversation: conversation, inbox: channel.inbox, message_type: :outgoing, content: 'hello')
  end

  before do
    create(:installation_config, name: 'EVOLUTIONGO_API_URL', value: 'https://evogo.test')
    create(:installation_config, name: 'EVOLUTIONGO_API_TOKEN', value: 'global-token')
    GlobalConfig.clear_cache
  end

  def stub_send(endpoint, returned_id: 'returned-id', status: 200)
    stub_request(:post, "https://evogo.test/#{endpoint}")
      .to_return(
        status: status,
        body: { data: { Info: { ID: returned_id } }, message: 'success' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  describe '#send_message' do
    it 'claims the source_id before the request so the webhook echo dedups' do
      stub_send('send/text')

      service.send_message('5511988887777', message)

      expect(message.reload.source_id).to be_present
    end

    it 'sends the claimed id to the API' do
      stub_send('send/text')

      service.send_message('5511988887777', message)

      expect(WebMock).to have_requested(:post, 'https://evogo.test/send/text')
        .with { |req| JSON.parse(req.body)['id'].present? }
    end

    it 'releases the claimed source_id when nothing was sent' do
      stub_send('send/text', status: 500)

      service.send_message('5511988887777', message)

      expect(message.reload.source_id).to be_nil
    end
  end

  describe '#send_message with attachments' do
    let(:message) do
      msg = create(:message, conversation: conversation, inbox: channel.inbox, message_type: :outgoing, content: 'caption text')
      msg.attachments.create!(account_id: channel.account_id, file_type: :image,
                              file: { io: StringIO.new('a'), filename: 'a.png', content_type: 'image/png' })
      msg.attachments.create!(account_id: channel.account_id, file_type: :image,
                              file: { io: StringIO.new('b'), filename: 'b.png', content_type: 'image/png' })
      msg.reload
    end

    it 'routes audio through send/media, since send/audio does not exist' do
      audio_message = create(:message, conversation: conversation, inbox: channel.inbox, message_type: :outgoing, content: '')
      audio_message.attachments.create!(account_id: channel.account_id, file_type: :audio,
                                        file: { io: StringIO.new('x'), filename: 'a.ogg', content_type: 'audio/ogg' })
      stub_send('send/media')

      service.send_message('5511988887777', audio_message.reload)

      expect(WebMock).to have_requested(:post, 'https://evogo.test/send/media')
        .with { |req| JSON.parse(req.body)['type'] == 'audio' }
    end

    it 'puts the caption on a single attachment only' do
      stub_send('send/media')

      service.send_message('5511988887777', message)

      expect(WebMock).to have_requested(:post, 'https://evogo.test/send/media').twice
      expect(WebMock).to have_requested(:post, 'https://evogo.test/send/media')
        .with { |req| JSON.parse(req.body)['caption'].present? }.once
    end
  end

  describe 'interactive messages' do
    def interactive_message(item_count)
      items = Array.new(item_count) { |i| { 'title' => "Option #{i}", 'value' => "opt_#{i}" } }
      create(
        :message,
        conversation: conversation,
        inbox: channel.inbox,
        message_type: :outgoing,
        content: 'Pick one',
        content_type: 'input_select',
        content_attributes: { 'items' => items }
      )
    end

    it 'sends three options or fewer as reply buttons' do
      stub_send('send/button')

      service.send_message('5511988887777', interactive_message(3))

      expect(WebMock).to have_requested(:post, 'https://evogo.test/send/button')
        .with { |req|
          payload = JSON.parse(req.body)
          payload['description'] == 'Pick one' &&
            payload['buttons'].length == 3 &&
            payload['buttons'].first == { 'type' => 'reply', 'displayText' => 'Option 0', 'id' => 'opt_0' }
        }
    end

    it 'sends more than three options as a list' do
      stub_send('send/list')

      service.send_message('5511988887777', interactive_message(4))

      expect(WebMock).to have_requested(:post, 'https://evogo.test/send/list')
        .with { |req|
          payload = JSON.parse(req.body)
          payload['sections'].first['rows'].length == 4 &&
            payload['sections'].first['rows'].first == { 'rowId' => 'opt_0', 'title' => 'Option 0' }
        }
    end

    it 'sends a null footer when the caller did not set one' do
      stub_send('send/button')

      service.send_message('5511988887777', interactive_message(2))

      expect(WebMock).to have_requested(:post, 'https://evogo.test/send/button')
        .with { |req| JSON.parse(req.body)['footer'].nil? }
    end

    # The list endpoint names the field footerText; sending `footer` leaves it out of the message.
    it 'sends the footer of a list under footerText' do
      stub_send('send/list')
      message = interactive_message(4)
      message.update!(content_attributes: message.content_attributes.merge('footer' => 'Loja'))

      service.send_message('5511988887777', message)

      expect(WebMock).to have_requested(:post, 'https://evogo.test/send/list')
        .with { |req| JSON.parse(req.body)['footerText'] == 'Loja' }
    end

    it 'forwards title and footer when they are present' do
      stub_send('send/button')
      message = interactive_message(2)
      message.update!(content_attributes: message.content_attributes.merge('title' => 'Menu', 'footer' => 'Loja'))

      service.send_message('5511988887777', message)

      expect(WebMock).to have_requested(:post, 'https://evogo.test/send/button')
        .with { |req| JSON.parse(req.body).values_at('title', 'footer') == %w[Menu Loja] }
    end

    it 'does not send the interactive message as plain text' do
      stub_send('send/button')

      service.send_message('5511988887777', interactive_message(2))

      expect(WebMock).not_to have_requested(:post, 'https://evogo.test/send/text')
    end
  end

  describe '#get_connection_status' do
    def stub_status(connected:, logged_in:)
      stub_request(:get, 'https://evogo.test/instance/status')
        .to_return(
          status: 200,
          body: { data: { Connected: connected, LoggedIn: logged_in, Name: 'Biz' } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'caches a live connection' do
      stub_status(connected: true, logged_in: true)

      result = service.get_connection_status(force_api_check: true)

      expect(result[:connected]).to be(true)
      expect(channel.reload.provider_config['connection_status']).to eq('open')
    end

    it 'writes the disconnected state back instead of leaving a stale open' do
      channel.merge_provider_config!('connected' => true, 'connection_status' => 'open')
      stub_status(connected: true, logged_in: false)

      service.get_connection_status(force_api_check: true)

      expect(channel.reload.provider_config['connected']).to be(false)
      expect(channel.provider_config['connection_status']).to eq('close')
    end

    it 'leaves a pairing attempt alone' do
      channel.merge_provider_config!('connection_status' => 'connecting')
      stub_status(connected: false, logged_in: false)

      service.get_connection_status(force_api_check: true)

      expect(channel.reload.provider_config['connection_status']).to eq('connecting')
    end
  end

  describe '#message_delay' do
    it 'treats delay_time as seconds' do
      channel.merge_provider_config!('delay_enabled' => true, 'delay_time' => 120)
      stub_send('send/text')

      service.send_message('5511988887777', message)

      expect(WebMock).to have_requested(:post, 'https://evogo.test/send/text')
        .with { |req| JSON.parse(req.body)['delay'] == 120_000 }
    end
  end

  describe '#get_pairing_code' do
    it 'registers the webhook before pairing, since /instance/pair takes no webhookUrl' do
      stub_request(:post, 'https://evogo.test/instance/connect').to_return(status: 200, body: '{}')
      stub_request(:post, 'https://evogo.test/instance/pair')
        .to_return(status: 200, body: { data: { PairingCode: '1234-5678' } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      service.get_pairing_code(phone_number: '5511988887777')

      expect(WebMock).to have_requested(:post, 'https://evogo.test/instance/connect')
    end
  end
end
