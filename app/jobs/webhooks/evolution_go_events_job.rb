class Webhooks::EvolutionGoEventsJob < ApplicationJob
  queue_as :high

  # Grace period given to whatsmeow's own reconnection before we confirm a close event
  CONNECTION_RECHECK_DELAY = 30.seconds

  def perform(params = {})
    @params = params.with_indifferent_access
    @event = @params[:event]
    @channel_id = @params[:channel_id]

    channel = Channel::Whatsapp.find_by(id: @channel_id)
    return if channel.blank? || channel.inbox.blank?

    case @event.to_s
    when 'Message'
      process_message_event(channel)
    when 'Receipt'
      process_receipt_event(channel)
    when 'PairSuccess'
      process_pair_success(channel)
    when 'CONNECTION'
      process_connection_event(channel)
    else
      Rails.logger.debug "[EVOLUTION_GO JOB] Unhandled event: #{@event}"
    end
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO JOB] Error: #{e.message}"
    raise # Re-raise for Sidekiq retry
  end

  private

  def process_message_event(channel)
    Whatsapp::IncomingMessageEvolutionGoService.new(
      inbox: channel.inbox,
      params: @params.to_h
    ).perform
  end

  def process_pair_success(channel)
    data = @params[:data] || {}
    business_name = data['BusinessName']
    jid = data['jid'] || data['ID']

    config = channel.provider_config || {}
    config['connection_status'] = 'open'
    config['connected'] = true
    config['business_name'] = business_name if business_name.present?
    config['jid'] = jid if jid.present?
    config['connected_at'] = Time.current.iso8601

    channel.update_column(:provider_config, config)

    # Clear reauthorization alert when the channel reconnects via QR/pairing
    channel.reauthorized! if channel.reauthorization_required?

    Rails.logger.info "[EVOLUTION_GO JOB] PairSuccess processed for channel #{channel.id}"
  end

  def process_connection_event(channel)
    data = @params[:data] || {}
    status = data['status'] || data['state']

    config = channel.provider_config || {}

    if status == 'open'
      config['connection_status'] = 'open'
      config['connected'] = true

      # Clear reauthorization alert when connection is restored
      channel.reauthorized! if channel.reauthorization_required?
    elsif %w[close closed].include?(status.to_s)
      config['connection_status'] = 'close'
      config['connected'] = false

      # Confirm the disconnection out of band instead of alerting right away: whatsmeow
      # reconnects on its own after network blips, and the alert stops message ingestion.
      Inboxes::CheckEvolutionGoConnectionsJob.set(wait: CONNECTION_RECHECK_DELAY).perform_later(channel.id)
    end

    channel.update_column(:provider_config, config)
    Rails.logger.info "[EVOLUTION_GO JOB] Connection event: #{status} for channel #{channel.id}"
  end

  def process_receipt_event(channel)
    Whatsapp::MessageStatusEvolutionGoService.new(
      inbox: channel.inbox,
      params: @params.to_h
    ).perform
  end
end
