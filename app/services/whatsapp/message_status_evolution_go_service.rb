# Service to process message status updates (Receipt events) from Evolution GO API
#
# Handles scenarios:
# 1. Delivered/ServerAck: Our outgoing message was delivered to the contact's phone
#    → Updates message status from "sent" to "delivered"
# 2. Read by contact: The contact opened and read our message
#    → Updates message status from "delivered" to "read"
# 3. ReadSelf: The agent read an incoming message on their phone
#    → Marks the conversation as read in Chatwoot (updates agent_last_seen_at)
# 4. PlayedSelf: The agent played an audio on their phone
#    → Treated same as ReadSelf
# 5. Empty state with empty Type: Delivery receipt from whatsmeow
#    → Treated as delivered
#
# Payload structure:
# {
#   "data": {
#     "Chat": "5527998999017@s.whatsapp.net",
#     "IsFromMe": false/true,
#     "MessageIDs": ["3EB04A0C6941DD79143466"],
#     "Timestamp": "2026-04-21T21:50:31-03:00",
#     "Type": "" | "read" | "read-self",
#     "MessageSender": "" | "5527998999017@s.whatsapp.net"
#   },
#   "event": "Receipt",
#   "state": "Delivered" | "Read" | "ReadSelf" | "ServerAck" | "PlayedSelf" | nil
# }

class Whatsapp::MessageStatusEvolutionGoService
  pattr_initialize [:inbox!, :params!]

  def perform
    return if data_params.blank?
    return if message_ids.blank?

    Rails.logger.info "[EVOLUTION_GO STATUS] Receipt: state=#{state} | type=#{data_params['Type']} | " \
                      "from_me=#{from_me?} | msg_ids=#{message_ids} | chat=#{data_params['Chat']} | " \
                      "sender=#{data_params['Sender']}"

    case state
    when 'Delivered', 'ServerAck'
      handle_delivered
    when 'Read'
      from_me? ? handle_read_by_agent : handle_read_by_contact
    when 'ReadSelf'
      handle_read_by_agent
    when 'PlayedSelf'
      # Audio played by agent on phone, treat as read
      handle_read_by_agent
    when nil, ''
      # EvoGO may send delivery receipts without state field (whatsmeow empty Type)
      # If Type is blank/empty and not from_me, treat as delivery receipt
      if data_params['Type'].blank? && !from_me?
        Rails.logger.info "[EVOLUTION_GO STATUS] Inferred delivery from empty state/type"
        handle_delivered
      else
        Rails.logger.warn "[EVOLUTION_GO STATUS] Empty state with type=#{data_params['Type']} from_me=#{from_me?}"
      end
    else
      Rails.logger.warn "[EVOLUTION_GO STATUS] Unhandled state: #{state} | full_params: #{params.except('evolution_go').to_json}"
    end
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO STATUS] Error: #{e.message}"
    Rails.logger.debug "[EVOLUTION_GO STATUS] Backtrace:\n#{e.backtrace.first(5).join("\n")}"
  end

  private

  def data_params
    @data_params ||= (params['data'] || params[:data] || {}).with_indifferent_access
  end

  def state
    params['state'] || params[:state]
  end

  def from_me?
    data_params['IsFromMe'] == true
  end

  def message_ids
    @message_ids ||= Array(data_params['MessageIDs']).compact
  end

  def receipt_timestamp
    ts = data_params['Timestamp']
    return Time.current if ts.blank?

    Time.parse(ts)
  rescue ArgumentError
    Time.current
  end

  # --- Delivered: Our message reached the contact's phone ---
  def handle_delivered
    updated = update_messages_status(:delivered, [:sent])
    Rails.logger.info "[EVOLUTION_GO STATUS] Delivered #{updated} message(s)" if updated.positive?
  end

  # --- Read by contact: Contact opened and read our outgoing message ---
  def handle_read_by_contact
    updated = update_messages_status(:read, %i[sent delivered])
    Rails.logger.info "[EVOLUTION_GO STATUS] Read by contact: #{updated} message(s)" if updated.positive?
  end

  # --- Read by agent on phone: Agent read incoming message on their phone ---
  # Updates agent_last_seen_at so the conversation is no longer "unread"
  def handle_read_by_agent
    messages = find_messages
    return if messages.blank?

    conversation_ids = messages.pluck(:conversation_id).uniq

    conversation_ids.each do |conv_id|
      conversation = Conversation.find_by(id: conv_id)
      next if conversation.blank?

      # Only update if the receipt timestamp is newer
      if conversation.agent_last_seen_at.blank? || conversation.agent_last_seen_at < receipt_timestamp
        conversation.update!(agent_last_seen_at: receipt_timestamp)
        conversation.dispatch_conversation_updated_event
        Rails.logger.info "[EVOLUTION_GO STATUS] Conversation #{conv_id} marked as read by agent (phone) and broadcasted"
      end
    end
  end

  # --- Helpers ---

  def find_messages
    Message.where(source_id: message_ids, inbox_id: inbox.id)
  end

  def update_messages_status(new_status, from_statuses)
    messages = find_messages.where(status: from_statuses, message_type: :outgoing)
    count = messages.count

    messages.find_each do |message|
      Messages::StatusUpdateService.new(message, new_status.to_s).perform
    end

    count
  end
end
