# Job to fetch media from Evolution API for messages sent directly from the phone.
#
# Strategy (see docs/example/incoming_messages.md):
# 1. When a messages.update with DELIVERY_ACK + fromMe arrives, it may be a media
#    message that was sent from the phone (audio, image, document).
# 2. We use the keyId to call Evolution API's getBase64FromMediaMessage endpoint.
# 3. The returned base64 data is attached to the existing message in Chatwoot.
#
# This only applies to outgoing messages (fromMe: true) that don't yet have attachments.
class Webhooks::EvolutionFetchMediaJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(message_id, channel_id, key_id)
    Rails.logger.info "[EVOLUTION FETCH MEDIA] Starting for Message #{message_id}, keyId: #{key_id}"

    message = Message.find_by(id: message_id)
    unless message
      Rails.logger.warn "[EVOLUTION FETCH MEDIA] Message #{message_id} not found, skipping"
      return
    end

    # Skip if message already has attachments
    if message.attachments.any?
      Rails.logger.info "[EVOLUTION FETCH MEDIA] Message #{message_id} already has attachments, skipping"
      return
    end

    channel = Channel::Whatsapp.find_by(id: channel_id)
    unless channel
      Rails.logger.warn "[EVOLUTION FETCH MEDIA] Channel #{channel_id} not found, skipping"
      return
    end

    # Call Evolution API to get base64 media
    service = Whatsapp::Providers::EvolutionService.new(whatsapp_channel: channel)
    media_response = service.get_base64_from_media_message(key_id)

    unless media_response
      Rails.logger.info "[EVOLUTION FETCH MEDIA] No media returned for keyId: #{key_id}, message may be text-only"
      return
    end

    # Extract media data from response
    # Evolution API can return: { "base64": "...", "mimetype": "audio/ogg", "fileName": "..." }
    # or sometimes nested in different structures
    media_data = extract_media_data(media_response)

    unless media_data[:base64].present?
      Rails.logger.info "[EVOLUTION FETCH MEDIA] No base64 content in response for keyId: #{key_id}"
      return
    end

    # Attach the media to the message
    attach_media(message, media_data)

    Rails.logger.info "[EVOLUTION FETCH MEDIA] ✅ Media attached to Message #{message_id}"
  end

  private

  def extract_media_data(response)
    # Handle different response formats from Evolution API
    if response.is_a?(Hash)
      {
        base64: response['base64'] || response[:base64],
        mimetype: response['mimetype'] || response[:mimetype] || 'application/octet-stream',
        fileName: response['fileName'] || response[:fileName]
      }
    elsif response.is_a?(Array) && response.first.is_a?(Hash)
      first = response.first
      {
        base64: first['base64'] || first[:base64],
        mimetype: first['mimetype'] || first[:mimetype] || 'application/octet-stream',
        fileName: first['fileName'] || first[:fileName]
      }
    else
      { base64: nil, mimetype: nil, fileName: nil }
    end
  end

  def attach_media(message, media_data)
    base64_data = media_data[:base64]
    mimetype = media_data[:mimetype] || 'application/octet-stream'
    filename = media_data[:fileName] || generate_filename(mimetype)

    # Remove data URI prefix if present (e.g., "data:audio/ogg;base64,...")
    base64_clean = base64_data.sub(%r{^data:.*?;base64,}, '')
    decoded = Base64.decode64(base64_clean)

    file_type = determine_file_type(mimetype)

    attachment = message.attachments.new(
      account_id: message.account_id,
      file_type: file_type
    )

    attachment.file.attach(
      io: StringIO.new(decoded),
      filename: filename,
      content_type: mimetype
    )
    attachment.save!

    # Touch the message to trigger ActionCable broadcast so the frontend updates
    message.attachments.reload
    message.touch
    message.save!

    Rails.logger.info "[EVOLUTION FETCH MEDIA] ✅ Attachment #{attachment.id} saved (type: #{file_type}, mime: #{mimetype})"
  end

  def determine_file_type(mimetype)
    case mimetype.to_s
    when /image/ then :image
    when /audio/ then :audio
    when /video/ then :video
    else :file
    end
  end

  def generate_filename(mimetype)
    ext = case mimetype.to_s
          when /jpeg/, /jpg/ then 'jpg'
          when /png/ then 'png'
          when /gif/ then 'gif'
          when /webp/ then 'webp'
          when /mp4/ then 'mp4'
          when /ogg/ then 'ogg'
          when /mp3/ then 'mp3'
          when /pdf/ then 'pdf'
          when /opus/ then 'ogg'
          else 'bin'
          end

    type_prefix = case mimetype.to_s
                  when /image/ then 'image'
                  when /audio/ then 'audio'
                  when /video/ then 'video'
                  else 'file'
                  end

    "#{type_prefix}_#{Time.current.to_i}.#{ext}"
  end
end
