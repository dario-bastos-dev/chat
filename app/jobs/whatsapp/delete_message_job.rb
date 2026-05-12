class Whatsapp::DeleteMessageJob < ApplicationJob
  queue_as :high

  def perform(message_id)
    message = Message.find(message_id)
    channel = message.inbox.channel
    external_id = message.source_id

    return if external_id.blank?

    # Get contact's phone number as the chat identifier
    # Evolution GO expects the JID or number, and we handle the JID formatting in the service
    phone_number = message.conversation.contact.phone_number
    return if phone_number.blank?

    channel.delete_message(phone_number, external_id)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "[WHATSAPP_DELETE_JOB] Message not found: #{message_id}"
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_DELETE_JOB] Error: #{e.message}"
  end
end
