# Service to process message status updates (Receipt events) from Evolution GO API
#
# Handles three scenarios:
# 1. Delivered: Our outgoing message was delivered to the contact's phone
#    → Updates message status from "sent" to "delivered"
# 2. Read by contact: The contact opened and read our message
#    → Updates message status from "delivered" to "read"
# 3. Read by agent on phone: The agent read an incoming message on their phone
#    → Marks the conversation as read in Chatwoot (updates agent_last_seen_at)
#
# Payload structure:
# {
#   "data": {
#     "Chat": "5527998999017@s.whatsapp.net",
#     "IsFromMe": false/true,
#     "MessageIDs": ["3EB04A0C6941DD79143466"],
#     "Timestamp": "2026-04-21T21:50:31-03:00",
#     "Type": "" | "read",
#     "MessageSender": "" | "5527998999017@s.whatsapp.net"
#   },
#   "event": "Receipt",
#   "state": "Delivered" | "Read"
# }

class Whatsapp::MessageStatusEvolutionGoService
  pattr_initialize [:inbox!, :params!]

  def perform
    return if data_params.blank?
    return if message_ids.blank?

    case state
    when 'Delivered'
      handle_delivered
    when 'Read'
      from_me? ? handle_read_by_agent : handle_read_by_contact
    else
      Rails.logger.debug "[EVOLUTION_GO STATUS] Unhandled state: #{state}"
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
