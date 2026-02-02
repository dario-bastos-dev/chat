# Service to process incoming messages from Evolution API (WhatsApp Lite)
# This is separate from WhatsApp Cloud API and has its own payload format
#
# Evolution API payload structure:
# {
#   "event": "messages.upsert",
#   "instance": "Instance Name",
#   "data": {
#     "key": {
#       "remoteJid": "number@s.whatsapp.net",
#       "fromMe": false,
#       "id": "message_id"
#     },
#     "pushName": "Contact Name",
#     "message": {
#       "conversation": "Message text here",
#       "mediaUrl":"https://example.com/media.jpg",
#     },
#     "messageType": "type of message",
#     "messageTimestamp": 1768305601
#   },
#   "sender": "number@s.whatsapp.net"
# }

class Whatsapp::IncomingMessageEvolutionService
  pattr_initialize [:inbox!, :params!]

  def perform
    # Normalize params to handle both symbol and string keys
    @normalized_params = normalize_params(params)
    
    # Early return if no data
    return if data_params.blank?

    # Filter out redundant message types (Broadcasts, Status)
    # Allow @g.us (Groups)
    return if remote_jid.to_s.match?(/(@broadcast|status)/)

    # Skip if no valid phone number
    if contact_phone_number.blank?
      Rails.logger.debug "[EVOLUTION MSG] Invalid phone: #{remote_jid}"
      return
    end

    # Distributed Lock to prevent race conditions
    # Ensures idempotency for the same message ID
    lock_key = "evol:msg:#{message_id}"
    
    # Simple check-and-set using Redis if available, or proceed if no Redis lock class
    if defined?(Redis::Lock)
      begin
        Redis::Lock.new(lock_key, expiration: 30, timeout: 0.1).lock do
          process_message_with_logging
        end
      rescue Redis::Lock::LockError
        Rails.logger.info "[EVOLUTION MSG] Duplicate processing prevented for #{message_id}"
      end
    else
      # Fallback if Redis::Lock not available
      process_message_with_logging
    end

  rescue StandardError => e
    Rails.logger.error "[EVOLUTION MSG] Error: #{e.message}"
    Rails.logger.debug "[EVOLUTION MSG] Backtrace:\n#{e.backtrace.first(5).join("\n")}"
    raise
  end

  private

  def process_message_with_logging
    # Log message direction
    direction = from_me? ? 'outgoing' : 'incoming'
    Rails.logger.info "[EVOLUTION MSG] #{direction} | #{contact_phone_number} | #{message_type_from_payload}"

    set_contact
    set_conversation  
    create_message
  end

  # Normalize params to ensure consistent access with string keys
  def normalize_params(p)
    # Convert to JSON and back to get plain Ruby Hash with string keys
    # This handles all edge cases with HashWithIndifferentAccess, symbols, etc.
    JSON.parse(p.to_json)
  rescue JSON::GeneratorError, JSON::ParserError => e
    Rails.logger.error "[EVOLUTION MSG] Failed to normalize params: #{e.message}"
    # Fallback to manual conversion
    deep_stringify(p)
  end

  # Recursively convert to hash with string keys (fallback)
  def deep_stringify(obj)
    case obj
    when Hash
      obj.to_h.transform_keys(&:to_s).transform_values { |v| deep_stringify(v) }
    when Array
      obj.map { |v| deep_stringify(v) }
    else
      obj
    end
  end

  # Access data object from normalized params
  def data_params
    @data_params ||= @normalized_params['data'] || {}
  end

  # Key object contains remoteJid, fromMe, id
  def key_params
    @key_params ||= data_params['key'] || {}
  end

  # Message object contains the actual message content
  def message_params
    @message_params ||= data_params['message'] || {}
  end

  # Remote JID - prefer the one without @lid suffix
  # remoteJid can be: "5527997774194@s.whatsapp.net" or "246085134118923@lid"
  # remoteJidAlt can be the alternative format
  # We need to use the one with @s.whatsapp.net (phone number format)
  def remote_jid
    return @remote_jid if defined?(@remote_jid)

    primary_jid = key_params['remoteJid'].to_s
    alt_jid = key_params['remoteJidAlt'].to_s

    Rails.logger.info "[EVOLUTION MSG] JID check: primary=#{primary_jid}, alt=#{alt_jid}"

    # Check if primary JID has @lid suffix (internal WhatsApp ID, not phone number)
    if primary_jid.include?('@lid')
      # Use alternative JID if available
      @remote_jid = alt_jid.present? ? alt_jid : primary_jid
    else
      # Primary JID is good (has phone number format)
      @remote_jid = primary_jid
    end

    Rails.logger.info "[EVOLUTION MSG] JID selected: #{@remote_jid}"
    @remote_jid
  end

  # The source_id for ContactInbox - must be ONLY digits (WhatsApp validation)
  # WhatsApp inbox requires source_id to match: /^\d{1,15}\z/
  def contact_source_id
    # Extract only digits from the JID
    phone = remote_jid.to_s.split('@').first
    # Ensure it's only digits
    phone.to_s.gsub(/\D/, '')
  end

  # Extract phone number from remoteJid (the part before @)
  def contact_phone_number
    return @contact_phone_number if defined?(@contact_phone_number)

    # Get the number part (before @)
    local_part = remote_jid.to_s.split('@').first
    
    # Strip device identifier if present (e.g. 55279998877:57)
    phone = local_part.to_s.split(':').first
    
    # Only format as phone if it looks like a phone number (all digits)
    if phone.present? && phone.match?(/^\d+$/)
      @contact_phone_number = "+#{phone}"
    else
      Rails.logger.warn "[EVOLUTION MSG] Invalid phone number format: #{local_part} (parsed: #{phone})"
      @contact_phone_number = nil
    end

    @contact_phone_number
  end

  # Push name (contact's display name)
  def push_name
    data_params['pushName']
  end

  # Is this message from us?
  def from_me?
    key_params['fromMe'] == true
  end

  # Is this message a group message?
  def is_group?
    remote_jid.to_s.include?('@g.us')
  end

  # Message ID for deduplication
  def message_id
    key_params['id']
  end

  # Message type from Evolution (conversation, imageMessage, etc)
  def message_type_from_payload
    data_params['messageType'] || 'conversation'
  end

  # Message timestamp
  def message_timestamp
    ts = data_params['messageTimestamp']
    ts.present? ? Time.at(ts.to_i) : Time.current
  end

  # Extract text content from different message types
  def text_content
    content = extract_raw_content
    
    # Check if we need to prepend sender name (Group Context)
    if is_group? && !from_me? && content.present?
      sender = sender_name_for_group
      return "**#{sender}**: #{content}"
    end
    
    content
  end
  
  def extract_raw_content
    # Regular text message
    message_params['conversation'] ||
    # Extended text message (with link preview, etc)
    message_params.dig('extendedTextMessage', 'text') ||
    # Image caption
    message_params.dig('imageMessage', 'caption') ||
    # Video caption
    message_params.dig('videoMessage', 'caption') ||
    # Document caption
    message_params.dig('documentMessage', 'caption') ||
    # Audio doesn't have text
    ''
  end
  
  def sender_name_for_group
    # In groups, 'pushName' usually refers to the participant who sent the message
    name = push_name
    
    # If no pushName, try to get phone from participant JID
    if name.blank?
      participant = key_params['participant'].to_s
      name = participant.split('@').first if participant.present?
    end
    
    name.presence || 'Membro do Grupo'
  end

  # Contact attributes for creating/updating contact
  def contact_attributes
    name = if is_group?
             # For groups, we don't want to use the participant's push_name as the Group Name
             # We use a generic name or keep existing. 
             "Grupo #{contact_phone_number}"
           else
             push_name.presence || contact_phone_number
           end

    {
      name: name,
      phone_number: contact_phone_number,
      identifier: remote_jid  # Full JID as identifier (e.g., 5527998999017@s.whatsapp.net)
    }
  end

  # Find or create contact and contact_inbox
  def set_contact
    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: contact_source_id,
      inbox: inbox,
      contact_attributes: contact_attributes
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact
  end

  # Find or create conversation
  def set_conversation
    @conversation = if inbox.lock_to_single_conversation
                      @contact_inbox.conversations.last
                    else
                      @contact_inbox.conversations.where.not(status: :resolved).last
                    end

    return if @conversation

    # Create new conversation
    @conversation = ::Conversation.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id
    )
  end

  # Create the message in the conversation
  def create_message
    # Check for duplicate message
    # Skip duplicates
    return if message_id.present? && Message.exists?(source_id: message_id)

    # Determine message type and sender based on fromMe flag
    if from_me?
      # Message sent from WhatsApp directly (outgoing)
      @message = @conversation.messages.create!(
        account_id: inbox.account_id,
        inbox_id: inbox.id,
        content: text_content,
        message_type: :outgoing,
        source_id: message_id,
        created_at: message_timestamp,
        # Assign to the conversation assignee (agent) if available, otherwise nil (system/bot)
        sender: @conversation.assignee
      )
    else
      # Message received from contact (incoming)
      @message = @conversation.messages.create!(
        account_id: inbox.account_id,
        inbox_id: inbox.id,
        content: text_content,
        message_type: :incoming,
        sender: @contact,
        source_id: message_id,
        created_at: message_timestamp
      )
    end

    # Process attachments if present
    process_attachments
  end

  # Handle media attachments - NOW ASYNC FOR PERFORMANCE
  def process_attachments
    return unless @message # Ensure message exists
    
    Rails.logger.info "[EVOLUTION DEBUG] Message Params Keys: #{message_params.keys}"
    Rails.logger.info "[EVOLUTION DEBUG] Audio Data Present: #{audio_data.present?}"

    media_payload = {
      image: image_data,
      video: video_data,
      audio: audio_data,
      file: document_data,
      sticker: sticker_data
    }.find { |_, data| data.present? }

    Rails.logger.info "[EVOLUTION DEBUG] Media Payload Found: #{media_payload.inspect}"

    return unless media_payload
    
    type, data = media_payload
    
    # Schedule background job for media processing
    # This releases the main worker immediately to handle other messages
    Webhooks::EvolutionMediaJob.perform_later(@message.id, data, type)
    
    Rails.logger.info "[EVOLUTION MSG] Media attachment scheduled for Message #{@message.id}"
  end
  
  # Called by Background Job (EvolutionMediaJob)
  public
  def attach_media_async(message, type, media_data)
    @message = message # Set context
    Rails.logger.info "[EVOLUTION ASYNC] Processing Media for Message #{message.id}"
    media_data = media_data.with_indifferent_access
    
    # Evolution API can send media in different ways:
    # 1. Direct URL in 'mediaUrl' field (MinIO integration) - PRIORITY
    # 2. Direct URL in 'url' field
    # 3. Base64 in 'base64' field
    
    # Note: message_params is not available here since we are in a fresh job context
    # We rely on media_data passed through
    
    # For MinIO integration, we might miss the top-level 'mediaUrl' if it wasn't passed down.
    # However, usually 'url' inside media_data is sufficient or we need to pass it explicitly.
    # To fix this, we should have passed the full context or the specific URL.
    # For now, we rely on standard 'url' or 'base64' present in the component data.
    
    url = media_data['url']
    base64 = media_data['base64']
    
    # Check if a special 'mediaUrl' was passed in media_data (we'll ensure to pass it if possible)
    media_url_from_minio = media_data['mediaUrl']
    url = media_url_from_minio if media_url_from_minio.present?

    Rails.logger.info "[EVOLUTION ASYNC] URL: #{url.to_s.truncate(50)} | MinIO: #{media_url_from_minio.present?}"

    success = false

    start_time = Time.current

    if url.present?
      Rails.logger.info "[EVOLUTION ASYNC] Attempting attach from URL"
      success = attach_from_url(type, url, media_data)
      
      # If processing the specific MinIO URL, delete the original after success
      if success && media_url_from_minio.present? && url == media_url_from_minio
        delete_original_minio_file(media_url_from_minio)
      end
    elsif base64.present?
      Rails.logger.info "[EVOLUTION ASYNC] Attempting attach from Base64"
      attach_from_base64(type, base64, media_data)
    else
      Rails.logger.warn "[EVOLUTION MSG] Media data present but no URL or base64"
    end
    
    elapsed = Time.current - start_time
    Rails.logger.info "[EVOLUTION] Media processed in #{elapsed.round(2)}s. Success: #{success}"
  end

  def attach_from_url(type, url, media_data)
    Rails.logger.info "[EVOLUTION MSG] Attaching #{type} from URL: #{url.to_s.truncate(100)}"
    
    # Use mimetype from payload if available, otherwise fallback
    mimetype = media_data['mimetype'].presence || mime_for_type(type)
    filename = media_data['fileName'].presence || generate_filename(type, mimetype)

    attachment = @message.attachments.new(
      account_id: @message.account_id,
      file_type: map_file_type(type)
    )
    
    # Download and attach with timeouts
    downloaded_io = URI.open(url, open_timeout: 10, read_timeout: 30)
    
    attachment.file.attach(
      io: downloaded_io,
      filename: filename,
      content_type: mimetype
    )
    attachment.save!
    
    @message.attachments.reload
    # Touch the message to ensure updated_at changes, forcing ActionCable broadcast
    @message.touch
    @message.save!
    
    Rails.logger.info "[EVOLUTION MSG] ✅ Attachment saved: #{attachment.id} with MIME: #{mimetype}"
    true
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION MSG] Failed to attach from URL: #{e.message}"
    false
  end

  def attach_from_base64(type, base64_data, media_data)
    Rails.logger.info "[EVOLUTION MSG] Attaching #{type} from base64"
    
    # Remove data URI prefix if present
    base64_clean = base64_data.sub(/^data:.*?;base64,/, '')
    decoded = Base64.decode64(base64_clean)
    
    mimetype = media_data['mimetype'] || mime_for_type(type)
    filename = media_data['fileName'] || generate_filename(type, mimetype)

    attachment = @message.attachments.new(
      account_id: @message.account_id,
      file_type: map_file_type(type)
    )
    
    attachment.file.attach(
      io: StringIO.new(decoded),
      filename: filename,
      content_type: mimetype
    )
    attachment.save!
    
    # Force message update to notify frontend via ActionCable that attachment is ready
    @message.attachments.reload
    @message.save!
    
    Rails.logger.info "[EVOLUTION MSG] ✅ Attachment saved from base64: #{attachment.id}"
    true
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION MSG] Failed to attach from base64: #{e.message}"
    false
  end

  def generate_filename(type, mimetype)
    ext = extension_for_mime(mimetype) || extension_for_type(type)
    "#{type}_#{Time.current.to_i}.#{ext}"
  end

  def extension_for_mime(mimetype)
    return nil unless mimetype.present?
    
    case mimetype
    when /jpeg/, /jpg/ then 'jpg'
    when /png/ then 'png'
    when /gif/ then 'gif'
    when /webp/ then 'webp'
    when /mp4/ then 'mp4'
    when /webm/ then 'webm'
    when /ogg/ then 'ogg'
    when /mp3/ then 'mp3'
    when /pdf/ then 'pdf'
    else nil
    end
  end

  def extension_for_type(type)
    case type
    when :image then 'jpg'
    when :video then 'mp4'
    when :audio then 'ogg'
    when :file then 'bin'
    else 'bin'
    end
  end

  def mime_for_type(type)
    text = type.to_s
    if text.include?('image')
      'image/jpeg'
    elsif text.include?('video')
      'video/mp4'
    elsif text.include?('audio')
      'audio/oga'
    elsif text.include?('application') || text.include?('file')
      'application/octet-stream'
    else
      'application/octet-stream'
    end
  end

  def map_file_type(type)
    case type.to_s
    when 'image', 'sticker' then :image
    when 'audio' then :audio
    when 'video' then :video
    else :file
    end
  end

  def image_data
    merge_media_url_if_present(message_params['imageMessage'])
  end

  def video_data
    merge_media_url_if_present(message_params['videoMessage'])
  end

  def audio_data
    merge_media_url_if_present(message_params['audioMessage'])
  end

  def document_data
    data = message_params['documentMessage'] || message_params['documentWithCaptionMessage']&.dig('message', 'documentMessage')
    merge_media_url_if_present(data)
  end

  def sticker_data
    merge_media_url_if_present(message_params['stickerMessage'])
  end

  private

  def merge_media_url_if_present(data)
    return nil unless data.present?
    
    # If mediaUrl exists in the payload, inject it into data
    # Evolution API usually places 'mediaUrl' in the root of 'data' (data_params),
    # but we also check message_params just in case.
    media_url = data_params['mediaUrl'] || message_params['mediaUrl']
    
    if media_url.present?
      data['mediaUrl'] = media_url
    end
    data
  end

  def delete_original_minio_file(url)
    return unless url.present?
    
    begin
      uri = URI.parse(url)
      path_parts = uri.path.split('/').reject(&:empty?)
      
      # Try to identify bucket and key
      bucket = ENV['AWS_S3_BUCKET_NAME']
      key = nil

      if bucket.present? && uri.path.start_with?("/#{bucket}/")
        # Structure: /bucket/key/path...
        key = uri.path.sub("/#{bucket}/", '')
      elsif path_parts.any?
        # Fallback: First segment is bucket
        bucket = path_parts.first
        key = path_parts.drop(1).join('/')
      end

      if bucket.present? && key.present?
        # Decode URL encoded characters (e.g., %40lid -> @lid)
        key = CGI.unescape(key)
        
        Rails.logger.info "[EVOLUTION MSG] Deleting original file from MinIO. Bucket: #{bucket}, Key: #{key}"
        s3_client.delete_object(bucket: bucket, key: key)
        Rails.logger.info "[EVOLUTION MSG] ✅ Deleted original file from MinIO"
      else
        Rails.logger.warn "[EVOLUTION MSG] Could not determine bucket/key from URL for deletion: #{url}"
      end
    rescue StandardError => e
      Rails.logger.error "[EVOLUTION MSG] Failed to delete from MinIO: #{e.message}"
    end
  end

  def s3_client
    @s3_client ||= Aws::S3::Client.new(
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
      region: ENV['AWS_REGION'] || 'us-east-1',
      endpoint: ENV['AWS_ENDPOINT'],
      force_path_style: ENV.fetch('AWS_FORCE_PATH_STYLE', 'true') == 'true'
    )
  end
end
