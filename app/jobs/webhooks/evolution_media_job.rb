class Webhooks::EvolutionMediaJob < ApplicationJob
  queue_as :default
  retry_on ActiveRecord::RecordNotFound, wait: 2.seconds, attempts: 5

  def perform(message_id, media_data, media_type)
    Rails.logger.info "[EVOLUTION MEDIA JOB] Starting for Message #{message_id}, Type: #{media_type}"
    message = Message.find(message_id) # Should raise RecordNotFound if not found, triggering retry
    
    service = Whatsapp::IncomingMessageEvolutionService.new(inbox: message.inbox, params: {})
    # Use the service helper to attach, but context is different now
    service.attach_media_async(message, media_type, media_data)
  end
end
