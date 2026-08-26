require 'rails_helper'

RSpec.describe 'Webhooks::EvolutionGoController', type: :request do
  let(:instance_token) { 'instance-token-abc' }
  let(:channel) do
    create(
      :channel_whatsapp,
      provider: 'evolution_go',
      provider_config: { 'instance_token' => instance_token, 'instance_id' => 'instance-id' },
      sync_templates: false,
      validate_provider_config: false,
      provider_instance_callbacks: false
    )
  end

  let(:phone) { channel.phone_number.delete('+') }

  def post_webhook(payload)
    post "/webhooks/evolution_go/#{phone}",
         params: payload.to_json,
         headers: { 'CONTENT_TYPE' => 'application/json' }
  end

  def message_payload(token: instance_token)
    {
      event: 'Message',
      instanceToken: token,
      data: {
        'Info' => {
          'ID' => 'msg-1',
          'IsFromMe' => false,
          'IsGroup' => false,
          'Sender' => '5511999999999@s.whatsapp.net',
          'Chat' => '5511999999999@s.whatsapp.net',
          'PushName' => 'Contact',
          'Type' => 'text'
        },
        'Message' => { 'conversation' => 'hello' }
      }
    }
  end

  before do
    channel
  end

  describe 'instance token authentication' do
    it 'enqueues the job when the token matches' do
      expect { post_webhook(message_payload) }
        .to have_enqueued_job(Webhooks::EvolutionGoEventsJob)

      expect(response).to have_http_status(:ok)
    end

    it 'drops the event when the token does not match' do
      expect { post_webhook(message_payload(token: 'forged-token')) }
        .not_to have_enqueued_job(Webhooks::EvolutionGoEventsJob)

      expect(response).to have_http_status(:ok)
    end

    it 'drops the event when the payload carries no token' do
      payload = message_payload.except(:instanceToken)

      expect { post_webhook(payload) }
        .not_to have_enqueued_job(Webhooks::EvolutionGoEventsJob)
    end

    it 'drops the event when the channel has no token stored' do
      channel.update_column(:provider_config, {})

      expect { post_webhook(message_payload) }
        .not_to have_enqueued_job(Webhooks::EvolutionGoEventsJob)
    end
  end

  describe 'unknown phone numbers' do
    it 'ignores a payload for a phone number with no channel' do
      expect { post "/webhooks/evolution_go/5500000000000", params: message_payload.to_json, headers: { 'CONTENT_TYPE' => 'application/json' } }
        .not_to have_enqueued_job(Webhooks::EvolutionGoEventsJob)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'inactive channels' do
    before { channel.prompt_reauthorization! }

    it 'drops ingestion events' do
      expect { post_webhook(message_payload) }
        .not_to have_enqueued_job(Webhooks::EvolutionGoEventsJob)
    end

    # The events that clear reauthorization must not be gated by it, otherwise the channel can
    # never recover on its own.
    it 'lets connection lifecycle events through' do
      payload = { event: 'PairSuccess', instanceToken: instance_token, data: { 'status' => 'open' } }

      expect { post_webhook(payload) }
        .to have_enqueued_job(Webhooks::EvolutionGoEventsJob)
    end
  end

  describe 'payload forwarding' do
    it 'forwards the payload without a duplicated wrapper key' do
      expect { post_webhook(message_payload) }
        .to have_enqueued_job(Webhooks::EvolutionGoEventsJob)
        .with { |payload|
          expect(payload).not_to have_key('evolution_go')
          expect(payload['channel_id']).to eq(channel.id)
        }
    end

    # The token authenticates the webhook, so it should not be parked in Redis or shown in the
    # Sidekiq admin UI once the check has already passed.
    it 'strips the instance token before enqueuing' do
      expect { post_webhook(message_payload) }
        .to have_enqueued_job(Webhooks::EvolutionGoEventsJob)
        .with { |payload| expect(payload).not_to have_key('instanceToken') }
    end
  end
end
