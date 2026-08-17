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
      # Warn, not debug: the connection event name is not documented anywhere, and this log
      # is how we find out what EvoGO actually sends when a number drops.
      Rails.logger.warn "[EVOLUTION_GO JOB] Unhandled event: #{@event.inspect} | " \
                        "data keys: #{(@params[:data] || {}).keys} | channel: #{@channel_id}"
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
    # Our own LID. Outgoing echoes address us by it in LID chats, so quoting one of our
    # messages there needs this and not the phone JID.
    lid = data['LID']

    updates = { 'connection_status' => 'open', 'connected' => true, 'connected_at' => Time.current.iso8601 }
    updates['business_name'] = business_name if business_name.present?
    updates['jid'] = jid if jid.present?
    updates['lid'] = lid if lid.present?

    channel.merge_provider_config!(updates)

    # Clear reauthorization alert when the channel reconnects via QR/pairing
    channel.reauthorized! if channel.reauthorization_required?

    Rails.logger.info "[EVOLUTION_GO JOB] PairSuccess processed for channel #{channel.id}"
  end

  def process_connection_event(channel)
    data = @params[:data] || {}
    status = data['status'] || data['state']

    if status == 'open'
      channel.merge_provider_config!('connection_status' => 'open', 'connected' => true)

      # Clear reauthorization alert when connection is restored
      channel.reauthorized! if channel.reauthorization_required?
    elsif %w[close closed].include?(status.to_s)
      channel.merge_provider_config!('connection_status' => 'close', 'connected' => false)

      # Confirm the disconnection out of band instead of alerting right away: whatsmeow
      # reconnects on its own after network blips, and the alert stops message ingestion.
      Inboxes::CheckEvolutionGoConnectionsJob.set(wait: CONNECTION_RECHECK_DELAY).perform_later(channel.id)
    end
    Rails.logger.info "[EVOLUTION_GO JOB] Connection event: #{status} for channel #{channel.id}"
  end

  def process_receipt_event(channel)
    Whatsapp::MessageStatusEvolutionGoService.new(
      inbox: channel.inbox,
      params: @params.to_h
    ).perform
  end
end
