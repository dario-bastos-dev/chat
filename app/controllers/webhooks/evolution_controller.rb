class Webhooks::EvolutionController < ActionController::API
  # Respond quickly to webhook - process async for better performance
  def process_payload
    payload = extract_payload
    event = payload['event'] || payload[:event]
    
    # Get phone number from URL parameter (most reliable)
    phone_number = extract_phone_number(params[:phone_number]) || 
                   extract_phone_number(payload['sender'] || payload[:sender])

    # Early return if no phone
    return head :ok if phone_number.blank?

    # Ignore presence updates (typing/recording) immediately to save DB calls
    return head :ok if event == 'presence.update'

    # Find channel with single optimized query
    channel = find_channel_by_phone(phone_number)

    # Validation checks - return early to avoid processing
    return head :ok if channel.blank?
    return head :ok if channel.provider != 'evolution'
    return head :ok if channel_is_inactive?(channel)

    # Log only essential info
    Rails.logger.info "[EVOLUTION] Webhook: #{event} | Channel: #{channel.id}"

    # ASYNC processing via Sidekiq (fast response to Evolution API)
    Webhooks::EvolutionEventsJob.perform_later(
      payload.merge('channel_id' => channel.id).deep_stringify_keys
    )
    
    head :ok
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION] Webhook error: #{e.message}"
    head :ok # Always respond 200 to prevent retries
  end

  private

  # Extract payload from different possible structures
  def extract_payload
    if params[:body].is_a?(Hash)
      params[:body].to_unsafe_h
    elsif params[:event].present?
      params.to_unsafe_h.except(:controller, :action, :phone_number)
    else
      params.to_unsafe_h.except(:controller, :action, :phone_number)
    end
  end

  # Extract phone number from JID or phone string
  def extract_phone_number(value)
    return nil if value.blank?
    phone = value.to_s.split('@').first.gsub(/^\+/, '')
    phone.presence
  end

  # Single optimized query to find channel (instead of 3 separate queries)
  def find_channel_by_phone(phone)
    return nil if phone.blank?
    
    normalized = phone.gsub(/^\+/, '')
    phone_variants = [phone, "+#{normalized}", normalized].uniq
    
    Channel::Whatsapp
      .where(provider: 'evolution', phone_number: phone_variants)
      .first
  end

  def channel_is_inactive?(channel)
    channel.blank? || 
    channel.reauthorization_required? || 
    !channel.account&.active?
  end
end
