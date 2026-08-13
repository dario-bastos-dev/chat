# Ingests the `history` webhook Meta sends after a coexistence onboarding: up to 180 days of 1:1 chats,
# split into phases (0: day 0-1, 1: day 1-90, 2: day 90-180) and delivered in chunks.
# https://developers.facebook.com/documentation/business-messaging/whatsapp/embedded-signup/onboarding-business-app-users/
class Whatsapp::HistorySyncService
  pattr_initialize [:inbox!, :params!]

  def perform
    entries = value[:history]
    return if entries.blank?

    entries.each { |entry| process_entry(entry) }
  end

  private

  def value
    @value ||= params.dig(:entry, 0, :changes, 0, :value) || {}
  end

  def channel
    @channel ||= inbox.channel
  end

  # The thread messages carry `from` but no `to`, so the business number is what tells an outgoing
  # message apart from an incoming one.
  def business_identifiers
    @business_identifiers ||= [value.dig(:metadata, :display_phone_number), channel.phone_number]
                              .compact_blank.map { |number| number.to_s.gsub(/\D/, '') }
  end

  def process_entry(entry)
    return mark_unavailable(entry[:errors]) if entry[:errors].present?

    Array.wrap(entry[:threads]).each { |thread| process_thread(thread) }
    update_progress(entry[:metadata] || {})
  end

  def process_thread(thread)
    contact_identifier = thread[:id]
    return if contact_identifier.blank?

    conversation = Array.wrap(thread[:messages])
                        .filter_map { |message| import_message(contact_identifier, message) }
                        .first

    align_conversation_timestamps(conversation)
  end

  # One failed message must not abort the rest of the chunk: Meta does not resend a chunk.
  def import_message(contact_identifier, message)
    service = Whatsapp::HistoryMessageService.new(
      inbox: inbox,
      params: build_message_payload(contact_identifier, message),
      outgoing_echo: outgoing?(message)
    )
    service.perform
    service.conversation
  rescue StandardError => e
    Rails.logger.error("[WHATSAPP HISTORY] Failed to import message #{message[:id]} on inbox #{inbox.id}: #{e.message}")
    # The dedup lock is held for a day and Meta never resends a chunk, so a half-imported message would
    # be skipped by any retry. Releasing it keeps the message recoverable.
    Whatsapp::MessageDedupLock.new(message[:id]).release! if message[:id].present?
    nil
  end

  # Rebuilds the payload in the shape the live ingestion path expects: incoming messages need the
  # `contacts` entry the history payload omits, outgoing ones need the `to` the echo path reads.
  def build_message_payload(contact_identifier, message)
    message_value = { messaging_product: 'whatsapp', metadata: value[:metadata] }

    if outgoing?(message)
      message_value[:message_echoes] = [message.merge(to: contact_identifier)]
    else
      message_value[:contacts] = [{ wa_id: contact_identifier }]
      message_value[:messages] = [message]
    end

    { entry: [{ changes: [{ field: 'history', value: message_value }] }] }.with_indifferent_access
  end

  def outgoing?(message)
    business_identifiers.include?(message[:from].to_s.gsub(/\D/, ''))
  end

  # Backfilled messages skip Message's conversation-activity callback, and chunks arrive newest phase
  # first, so the timestamps are derived from the messages the conversation actually holds. Without this
  # a conversation rebuilt from six month old chats would sort as if it had just been active.
  #
  # Restricted to conversations the backfill itself created: when history lands in a contact's existing
  # open conversation, dragging its created_at back six months would distort the live reports.
  def align_conversation_timestamps(conversation)
    return if conversation.blank?
    return if conversation.additional_attributes['history_sync'].blank?

    oldest = conversation.messages.minimum(:created_at)
    newest = conversation.messages.maximum(:created_at)
    return if newest.blank?

    # waiting_since is stamped with the creation time by Conversation, which would report every imported
    # chat as a customer waiting since today. Clearing it is honest: if the customer writes again, the
    # live message path sets it. Reports and SLA then only see real waits.
    #
    # agent_last_seen_at moves to the business's last reply so the import doesn't land as a pile of
    # unread messages, while anything the customer sent after that reply stays correctly unread.
    # rubocop:disable Rails/SkipsModelValidations
    conversation.update_columns(
      created_at: oldest,
      last_activity_at: newest,
      waiting_since: nil,
      agent_last_seen_at: conversation.messages.outgoing.maximum(:created_at)
    )
    # rubocop:enable Rails/SkipsModelValidations
  end

  def update_progress(metadata)
    progress = metadata[:progress].to_i

    channel.update_history_sync!(
      status: progress >= 100 ? 'completed' : 'receiving',
      progress: progress,
      phase: metadata[:phase]
    )
  end

  def mark_unavailable(errors)
    message = Array.wrap(errors).first.to_h.values_at('title', 'message', 'details').compact_blank.first
    Rails.logger.warn("[WHATSAPP HISTORY] Sync reported an error on inbox #{inbox.id}: #{message}")
    channel.update_history_sync!(status: 'unavailable', error: message)
  end
end
