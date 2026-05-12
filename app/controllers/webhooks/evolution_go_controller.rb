class Webhooks::EvolutionGoController < ActionController::API
  def process_payload
    payload = extract_payload
    event = payload['event'] || payload[:event]

    phone_number = extract_phone_number(params[:phone_number]) ||
                   extract_phone_number(payload['sender'] || payload[:sender])

    return head :ok if phone_number.blank?

    # Ignore presence updates immediately
    return head :ok if event.to_s == 'presence.update'

    channel = find_channel_by_phone(phone_number)

    return head :ok if channel.blank?
    return head :ok if channel.provider != 'evolution_go'
    return head :ok if channel_is_inactive?(channel)

    Rails.logger.info "[EVOLUTION_GO] Webhook: #{event} | Channel: #{channel.id}"

    # ASYNC processing via Sidekiq (fast response to Evolution GO API)
    Webhooks::EvolutionGoEventsJob.perform_later(
      payload.merge('channel_id' => channel.id).deep_stringify_keys
    )

    head :ok
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] Webhook error: #{e.class} - #{e.message}"
    head :ok # Always respond 200 to prevent retries
  end

  private

  def extract_payload
    # EvoGO wraps payload in 'body' key
    raw = if params[:body].is_a?(Hash)
            params[:body].to_unsafe_h
          elsif params[:event].present?
            params.to_unsafe_h.except(:controller, :action, :phone_number)
          else
            params.to_unsafe_h.except(:controller, :action, :phone_number)
          end

    # EvoGO may nest data inside 'body'
    raw
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
