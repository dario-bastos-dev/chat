class Webhooks::EvolutionGoController < ActionController::API
  # ParamsWrapper would nest a duplicate of the whole payload under an "evolution_go" key,
  # doubling what gets handed to Sidekiq.
  wrap_parameters false

  # Events that write into a conversation. Everything else EvoGO sends is connection
  # lifecycle, which has to reach the job even on an inactive channel.
  INGESTION_EVENTS = %w[Message Receipt].freeze

  def process_payload
    payload = extract_payload
    event = payload['event'] || payload[:event]

    phone_number = extract_phone_number(params[:phone_number]) ||
                   extract_phone_number(payload['sender'] || payload[:sender])

    return head :ok if phone_number.blank?

    channel = find_channel_by_phone(phone_number)

    return head :ok if channel.blank?
    return head :ok if channel.provider != 'evolution_go'
    return head :ok unless instance_token_valid?(channel, payload)

    # Gate ingestion on an active channel, not connection lifecycle: an allowlist of
    # lifecycle event names would deadlock the channel if one of those names is wrong,
    # since reauthorization is cleared by exactly those events.
    return head :ok if INGESTION_EVENTS.include?(event.to_s) && channel_is_inactive?(channel)

    Rails.logger.info "[EVOLUTION_GO] Webhook: #{event} | Channel: #{channel.id}"

    # ASYNC processing via Sidekiq (fast response to Evolution GO API).
    # instanceToken is dropped: it was already checked above and nothing downstream reads it,
    # so keeping it would park the credential in Redis and in the Sidekiq admin UI.
    Webhooks::EvolutionGoEventsJob.perform_later(
      payload.except('instanceToken', :instanceToken).merge('channel_id' => channel.id).deep_stringify_keys
    )

    head :ok
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] Webhook error: #{e.class} - #{e.message}"
    head :ok # Always respond 200 to prevent retries
  end

  private

  # The webhook URL carries only the phone number, which is public knowledge, so it proves
  # nothing about the caller. EvoGO stamps every event with the instance token, and that is
  # what ties the payload to our instance.
  def instance_token_valid?(channel, payload)
    expected = channel.provider_config&.dig('instance_token').to_s
    received = (payload['instanceToken'] || payload[:instanceToken]).to_s

    return true if expected.present? && ActiveSupport::SecurityUtils.secure_compare(expected, received)

    Rails.logger.warn "[EVOLUTION_GO] Webhook rejected, instance token mismatch | Channel: #{channel.id} | " \
                      "Event: #{payload['event'] || payload[:event]} | Token received: #{received.present?}"
    false
  end

  # EvoGO posts data/event/instanceId/instanceName/instanceToken at the root.
  def extract_payload
    params.to_unsafe_h.except(:controller, :action, :phone_number)
  end

  def extract_phone_number(value)
    return nil if value.blank?

    phone = value.to_s.split('@').first.gsub(/^\+/, '')
    phone.presence
  end

  def find_channel_by_phone(phone)
    return nil if phone.blank?

    normalized = phone.gsub(/^\+/, '')
    phone_variants = [phone, "+#{normalized}", normalized].uniq

    Channel::Whatsapp
      .where(provider: 'evolution_go', phone_number: phone_variants)
      .first
  end

  def channel_is_inactive?(channel)
    channel.blank? ||
      channel.reauthorization_required? ||
      !channel.account&.active?
  end
end
