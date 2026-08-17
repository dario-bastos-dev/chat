class Webhooks::EvolutionGoMediaJob < ApplicationJob
  queue_as :medium

  # The message is created and committed by the ingestion service before this is enqueued, but
  # the enqueue can win the race against the commit.
  retry_on ActiveRecord::RecordNotFound, wait: 2.seconds, attempts: 5

  def perform(message_id, url, file_type, filename, content_type)
    message = Message.find(message_id)
    return if message.attachments.any?

    SafeFetch.fetch(url, validate_content_type: false) do |result|
      attachment = message.attachments.new(account_id: message.account_id, file_type: file_type)
      attachment.file.attach(
        io: result.tempfile,
        filename: filename,
        content_type: content_type.presence || result.content_type.presence || 'application/octet-stream'
      )
      attachment.save!
    end

    # The attachment is a separate record, so the message row is untouched and the dashboard
    # would keep showing an empty bubble. Touching it fires dispatch_update_event.
    message.touch

    Rails.logger.info "[EVOLUTION_GO MEDIA] Attached #{file_type} to Message #{message_id}"
  rescue SafeFetch::Error => e
    Rails.logger.error "[EVOLUTION_GO MEDIA] Fetch failed for Message #{message_id}: #{e.class} - #{e.message}"
  end
end
