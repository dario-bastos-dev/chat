class Webhooks::EvolutionGoEventsJob < MutexApplicationJob
  queue_as :high
  # Retry budget (19 x 2s = 38s) must exceed the 30s lock TTL used below, otherwise a webhook
  # that arrives just after the lock is taken can exhaust its retries before the holder finishes
  # and silently drop its message. Same budget as Webhooks::WhatsappEventsJob.
  retry_on LockAcquisitionError, wait: 2.seconds, attempts: 20

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
  # A lock conflict is the normal path when two webhooks for the same chat land together; it is
  # retried, not a failure, so it must not reach the error log the deploy is grepped for.
  rescue LockAcquisitionError
    raise
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO JOB] Error: #{e.message}"
    raise # Re-raise for Sidekiq retry
  end

  private

  # A message from the contact and the echo of an auto-reply sent by WhatsApp itself arrive as
  # two concurrent webhooks. Both look for an open conversation, neither finds one because the
  # other has not committed yet, and each creates its own. Serializing per (inbox, chat) lets
  # the first one create the conversation and the second append to it.
  def process_message_event(channel)
    chat_id = chat_lock_id
    return deliver_message_event(channel) if chat_id.blank?

    # 30s TTL, matching Webhooks::WhatsappEventsJob: the default 1s expires while the media
    # download and the transaction are still running, which lets the other webhook back in.
    key = format(::Redis::Alfred::WHATSAPP_MESSAGE_MUTEX, inbox_id: channel.inbox.id, sender_id: chat_id)
    with_lock(key, 30.seconds) { deliver_message_event(channel) }
  end

  def deliver_message_event(channel)
    Whatsapp::IncomingMessageEvolutionGoService.new(
      inbox: channel.inbox,
      params: @params.to_h
    ).perform
  end

  # Both webhooks of the same chat have to land on one key, and EvoGO does not address them the
  # same way. An observed pair: the incoming message carried Chat=<phone>@s.whatsapp.net while
  # the echo of the same chat carried Chat=<contact lid>@lid and put the phone in RecipientAlt.
  # So the phone JID is preferred wherever it shows up — that is the one field both payloads
  # share — and Chat is the fallback for chats addressed only by LID, where it names the contact
  # in both directions. Same preference the incoming service applies to resolve contact_jid.
  # The `:device` suffix is stripped for the same reason the incoming service strips it.
  def chat_lock_id
    info = @params[:data].is_a?(Hash) ? (@params[:data][:Info] || {}) : {}
    candidates = [info[:RecipientAlt], info[:Chat], info[:Sender], info[:SenderAlt]]
                 .map { |jid| jid.to_s.gsub(/:[^@]+/, '') }.compact_blank

    preferred_lock_jid(candidates)
  end

  # A group comes first: it is one chat shared by everyone in it, and Sender names the participant
  # who spoke. Preferring the phone jid would lock per member instead of per group, and would make a
  # member's own 1:1 chat wait on a lock taken for the group.
  def preferred_lock_jid(candidates)
    candidates.find { |jid| jid.end_with?('@g.us') } ||
      candidates.find { |jid| jid.end_with?('@s.whatsapp.net') } ||
      candidates.first
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
