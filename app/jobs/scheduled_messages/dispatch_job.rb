class ScheduledMessages::DispatchJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    # Dispatch all pending scheduled messages that have reached their scheduled time
    ScheduledMessage.dispatchable.find_each do |scheduled_message|
      ActiveRecord::Base.transaction do
        # Build message attributes
        message_attrs = {
          account_id: scheduled_message.account_id,
          inbox_id: scheduled_message.conversation.inbox_id,
          content: scheduled_message.content,
          message_type: :outgoing,
          sender: scheduled_message.created_by
        }

        # Include template_params for WhatsApp Business Cloud
        if scheduled_message.template_params.present?
          message_attrs[:additional_attributes] = { 'template_params' => scheduled_message.template_params }
        end

        # Create message in conversation
        message = scheduled_message.conversation.messages.create!(message_attrs)

        # Execute dispatch to channel (hook into standard outgoing message flow)
        # This usually happens automatically via callbacks on Message creation,
        # but if we need explicit push, we can wrap it here.

        # Mark as sent
        scheduled_message.sent!
      rescue StandardError => e
        Rails.logger.error "Failed to dispatch scheduled message #{scheduled_message.id}: #{e.message}"
      end
    end
  end
end
