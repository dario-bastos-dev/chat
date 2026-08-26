class Whatsapp::DeleteMessageJob < ApplicationJob
  queue_as :high

  def perform(message_id)
    message = Message.find(message_id)
    channel = message.inbox.channel

    # A multi-attachment message was delivered as several WhatsApp messages; deleting only
    # source_id would leave the rest on the contact's phone.
    external_ids = [message.source_id, *Array(message.content_attributes&.dig('external_ids'))].compact_blank.uniq
    return if external_ids.blank?

    # Get contact's phone number as the chat identifier
    # Evolution GO expects the JID or number, and we handle the JID formatting in the service
    phone_number = message.conversation.contact.phone_number
    return if phone_number.blank?

    external_ids.each { |external_id| channel.delete_message(phone_number, external_id) }
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "[WHATSAPP_DELETE_JOB] Message not found: #{message_id}"
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_DELETE_JOB] Error: #{e.message}"
  end
end
