class Webhooks::EvolutionEventsJob < ApplicationJob
  queue_as :high  # High priority for real-time messaging

  def perform(params = {})
    @params = params.with_indifferent_access
    @event = @params[:event]
    @channel_id = @params[:channel_id]

    channel = Channel::Whatsapp.find_by(id: @channel_id)
    return if channel.blank? || channel.inbox.blank?

    # Handle different event types
    event_name = @event.to_s.downcase.tr('.', '_')
    
    case event_name
    when 'messages_upsert', 'send_message'
      process_message_event(channel)
    when 'messages_update'
      process_message_update(channel)
    when 'connection_update'
      process_connection_update(channel)
    when 'qrcode_updated'
      process_qrcode_update(channel)
    else
      Rails.logger.debug "[EVOLUTION JOB] Unhandled event: #{event_name}"
    end
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION JOB] Error: #{e.message}"
    raise # Re-raise for Sidekiq retry
  end

  private

  def process_message_event(channel)
    Whatsapp::IncomingMessageEvolutionService.new(
      inbox: channel.inbox, 
      params: @params.to_h
    ).perform
  end

  def process_message_update(channel)
    Whatsapp::UpdateMessageEvolutionService.new(
      inbox: channel.inbox, 
      params: @params.to_h
    ).perform
  end

  def process_connection_update(channel)
    data = @params[:data] || {}
    state = data[:state] || data['state']

    case state.to_s
    when 'open'
      channel.update_column(:provider_config, channel.provider_config.merge('connected' => true))
    when 'close', 'connecting'
      channel.update_column(:provider_config, channel.provider_config.merge('connected' => false))
    end
  end

  def process_qrcode_update(channel)
    data = @params[:data] || {}
    qr_code = data[:qrcode] || data['qrcode'] || data[:base64] || data['base64']

    return if qr_code.blank?
    
    channel.update_column(:provider_config, channel.provider_config.merge(
      'qr_code' => qr_code,
      'qr_code_updated_at' => Time.current.to_s
    ))
  end
end
