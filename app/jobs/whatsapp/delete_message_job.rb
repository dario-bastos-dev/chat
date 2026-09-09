class Whatsapp::DeleteMessageJob < ApplicationJob
  queue_as :high

  def perform(message_id)
    message = Message.find(message_id)
    channel = message.inbox.channel

    # A multi-attachment message was delivered as several WhatsApp messages; deleting only
    # source_id would leave the rest on the contact's phone.
    external_ids = [message.source_id, *Array(message.content_attributes&.dig('external_ids'))].compact_blank.uniq
    return if external_ids.blank?

    chat_id = chat_id_for(message)
    return if chat_id.blank?

    external_ids.each { |external_id| channel.delete_message(chat_id, external_id) }
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "[WHATSAPP_DELETE_JOB] Message not found: #{message_id}"
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_DELETE_JOB] Error: #{e.message}"
  end

  private

  # The contact_inbox source_id is the address WhatsApp actually uses for this chat, and it is the
  # only one that always exists: a group has no phone number, and neither does a contact known so
  # far only by its LID. Evolution GO takes a JID or a number, and the service formats the JID.
  def chat_id_for(message)
    message.conversation.contact_inbox&.source_id.presence || message.conversation.contact.phone_number
  end
end
