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

    # Filter out redundant message types (Broadcasts, Status, Groups)
    # Groups (@g.us) are not supported as individual conversations in Chatwoot
    # Also filter @lid JIDs that couldn't be resolved to a phone number
    return if remote_jid.to_s.match?(/(@broadcast|status)/)
    return if is_group? # Skip group messages - Chatwoot doesn't support group conversations

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
    set_contact_avatar
    set_conversation  
    create_message

    # Save LID→phone mapping when addressingMode is "lid"
    # This ensures future messages.update with @lid JID can resolve to this contact
    save_lid_mapping_if_needed
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

  # Remote JID - prefer the one with @s.whatsapp.net (phone number format)
  # remoteJid can be: "5527997774194@s.whatsapp.net", "246085134118923@lid", or "120363403723253389@g.us"
  # For @lid JIDs, we use participantAlt which has the real phone number
  def remote_jid
    return @remote_jid if defined?(@remote_jid)

    primary_jid = key_params['remoteJid'].to_s
    alt_jid = key_params['remoteJidAlt'].to_s
    participant_alt = key_params['participantAlt'].to_s

    Rails.logger.info "[EVOLUTION MSG] JID check: primary=#{primary_jid}, alt=#{alt_jid}, participantAlt=#{participant_alt}"

    @remote_jid = if primary_jid.include?('@lid')
                    # Internal WhatsApp ID (@lid) - try alternatives
                    if alt_jid.present? && alt_jid.include?('@s.whatsapp.net')
                      alt_jid
                    elsif participant_alt.present? && participant_alt.include?('@s.whatsapp.net')
                      participant_alt
                    else
                      primary_jid
                    end
                  elsif primary_jid.include?('@g.us')
                    # Group JID - keep as-is for group detection, 
                    # but for contact creation we'll need participantAlt
                    primary_jid
                  else
                    # Regular @s.whatsapp.net JID - good as-is
                    primary_jid
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
  # Ensures the number is in valid E.164 format (+ followed by 1-15 digits)
  def contact_phone_number
    return @contact_phone_number if defined?(@contact_phone_number)

    # Get the number part (before @)
    local_part = remote_jid.to_s.split('@').first
    
    # Strip device identifier if present (e.g. 55279998877:57)
    phone = local_part.to_s.split(':').first
    
    # Validate: must be all digits AND between 7-15 digits (E.164 range)
    # This prevents group IDs (18+ digits) and internal IDs from being used as phone numbers
    if phone.present? && phone.match?(/^\d{7,15}$/)
      @contact_phone_number = "+#{phone}"
    else
      Rails.logger.warn "[EVOLUTION MSG] Invalid phone number format: #{local_part} (parsed: #{phone}, length: #{phone&.length})"
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
           elsif from_me?
             # When fromMe=true, pushName is OUR name, not the contact's.
             # Use just the phone number — the contact's real name will be set
             # when they send a message (fromMe=false) with their pushName.
             contact_phone_number
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

    # When fromMe=false and the contact has pushName, update the contact's name
    # if it currently looks like a phone number (was set from a fromMe=true message)
    update_contact_name_if_needed
  end

  # Update contact name when we receive a message FROM the contact (fromMe=false)
  # and the contact currently has a phone-number-style name (e.g., "+5527997774194")
  def update_contact_name_if_needed
    return if from_me?
    return if is_group?
    return if push_name.blank?
    return unless @contact.present?

    current_name = @contact.name.to_s

    # Only update if the current name looks like a phone number
    # (starts with + and digits, or is just digits, or matches the contact_phone_number)
    is_phone_name = current_name.match?(/\A\+?\d+\z/) || current_name == contact_phone_number

    return unless is_phone_name

    @contact.update!(name: push_name)
    Rails.logger.info "[EVOLUTION MSG] Updated contact #{@contact.id} name: '#{current_name}' → '#{push_name}'"
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION MSG] Failed to update contact name: #{e.message}"
  end

  # Fetch and set contact avatar from Evolution API or jpegThumbnail
  # Only runs for contacts without an avatar (new contacts)
  def set_contact_avatar
    return if @contact.blank?
    return if @contact.avatar.attached?
    return if from_me? # Don't set avatar from our own messages

    # Extract jpegThumbnail bytes from message payload (if present)
    thumbnail_bytes = extract_jpeg_thumbnail

    Rails.logger.info "[EVOLUTION MSG] Scheduling avatar fetch for Contact #{@contact.id} (thumbnail: #{thumbnail_bytes.present?})"

    # Schedule background job to fetch avatar (won't block message processing)
    Webhooks::EvolutionContactAvatarJob.perform_later(
      @contact.id,
      inbox.id,
      remote_jid,
      thumbnail_bytes
    )
  rescue StandardError => e
    # Never fail message processing because of avatar
    Rails.logger.warn "[EVOLUTION MSG] Avatar scheduling failed: #{e.message}"
  end

  # Extract jpegThumbnail from the message payload
  # It can be found inside imageMessage, videoMessage, stickerMessage, etc.
  def extract_jpeg_thumbnail
    # Try each message type that can have a thumbnail
    %w[imageMessage videoMessage stickerMessage documentMessage].each do |msg_type|
      msg_data = message_params[msg_type]
      next unless msg_data.is_a?(Hash)

      thumbnail = msg_data['jpegThumbnail']
      return thumbnail if thumbnail.present?
    end

    nil
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
    
    Rails.logger.info "[EVOLUTION DEBUG] Message type: #{message_type_from_payload} | fromMe: #{from_me?}"
    Rails.logger.info "[EVOLUTION DEBUG] Message Params Keys: #{message_params.keys}"
    Rails.logger.info "[EVOLUTION DEBUG] Top-level mediaUrl present: #{data_params['mediaUrl'].present?}"

    media_payload = {
      image: image_data,
      video: video_data,
      audio: audio_data,
      file: document_data,
      sticker: sticker_data
    }.find { |_, data| data.present? }

    Rails.logger.info "[EVOLUTION DEBUG] Media Payload Found: #{media_payload&.first}"

    return unless media_payload
    
    type, data = media_payload
    
    # Sanitize media data: remove huge binary blobs (fileSha256, mediaKey, jpegThumbnail, etc.)
    # that cause Sidekiq serialization failures. Keep only essential fields.
    sanitized_data = sanitize_media_data(data)
    
    Rails.logger.info "[EVOLUTION DEBUG] Sanitized data keys: #{sanitized_data.keys} | url: #{sanitized_data['url'].to_s.truncate(60)} | mediaUrl: #{sanitized_data['mediaUrl'].to_s.truncate(60)}"
    
    # Schedule background job for media processing
    # This releases the main worker immediately to handle other messages
    Webhooks::EvolutionMediaJob.perform_later(@message.id, sanitized_data, type)
    
    Rails.logger.info "[EVOLUTION MSG] Media attachment scheduled for Message #{@message.id} (type: #{type}, fromMe: #{from_me?})"
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
      # Also set as the primary 'url' if the existing url is a WhatsApp CDN URL
      # (which expires quickly and is not accessible from the server)
      existing_url = data['url'].to_s
      if existing_url.blank? || existing_url.include?('mmg.whatsapp.net')
        data['url'] = media_url
      end
    end
    data
  end

  # Sanitize media data to remove huge binary blob fields that cause
  # Sidekiq serialization issues. Evolution API sends fields like fileSha256,
  # mediaKey, jpegThumbnail, fileEncSha256, scansSidecar, etc. as objects with
  # hundreds of numeric keys representing raw bytes.
  def sanitize_media_data(data)
    return {} unless data.is_a?(Hash)
    
    # Only keep essential fields needed for media attachment
    essential_keys = %w[
      url mediaUrl mimetype fileName caption base64
      fileLength height width directPath seconds ptt
    ]
    
    sanitized = {}
    essential_keys.each do |key|
      value = data[key]
      next if value.nil?
      
      # Skip if the value is a large hash (binary blob)
      if value.is_a?(Hash) && key == 'fileLength'
        # fileLength has {low: N, high: N, unsigned: bool} - extract the number
        sanitized[key] = value['low'] || value[:low]
      elsif value.is_a?(Hash)
        next # Skip other hash values (likely binary blobs)
      else
        sanitized[key] = value
      end
    end
    
    sanitized
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

  # ---- LID Mapping ----
  # The Evolution API may send the LID in either remoteJid or remoteJidAlt.
  # When one field is @lid and the other is @s.whatsapp.net, we can map LID↔phone directly.
  # The messages.update (DELIVERY_ACK) only has the @lid JID, so we need this mapping
  # to resolve the correct contact for media recovery.
  #
  # LID extraction strategy (in priority order):
  #   1. Compare remoteJid vs remoteJidAlt — if one is @lid and the other @s.whatsapp.net
  #   2. If addressingMode is "lid" and remoteJid is @lid → extract directly
  #   3. If addressingMode is "lid" and mediaUrl contains @lid → extract from URL path
  def save_lid_mapping_if_needed
    return unless @contact.present?

    lid_value = extract_lid_for_mapping
    return if lid_value.blank?

    # We have: LID, phone number (from contact), and contact
    phone = @contact.phone_number
    return if phone.blank?

    Channel::WhatsappLidMapping.create_or_update_mapping!(
      lid: lid_value,
      phone_number: phone,
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: @contact.id
    )
  rescue StandardError => e
    # LID mapping is non-critical; don't break message processing
    Rails.logger.error "[EVOLUTION MSG] Failed to save LID mapping: #{e.message}"
  end

  # Extract LID value from available sources (in priority order)
  def extract_lid_for_mapping
    primary_jid = key_params['remoteJid'].to_s
    alt_jid = key_params['remoteJidAlt'].to_s

    # ---- Source 1 (highest priority): Compare remoteJid vs remoteJidAlt ----
    # If one is @lid and the other is @s.whatsapp.net, we have a direct LID↔phone pair
    primary_is_lid = primary_jid.include?('@lid')
    alt_is_lid = alt_jid.include?('@lid')
    primary_is_phone = primary_jid.include?('@s.whatsapp.net')
    alt_is_phone = alt_jid.include?('@s.whatsapp.net')

    # Case A: remoteJid is @lid, remoteJidAlt is @s.whatsapp.net
    if primary_is_lid && alt_is_phone
      lid_value = extract_lid_digits(primary_jid)
      return lid_value if lid_value.present?
    end

    # Case B: remoteJid is @s.whatsapp.net, remoteJidAlt is @lid
    if primary_is_phone && alt_is_lid
      lid_value = extract_lid_digits(alt_jid)
      return lid_value if lid_value.present?
    end

    # Case C: Both are @lid (rare, but handle it)
    if primary_is_lid
      lid_value = extract_lid_digits(primary_jid)
      return lid_value if lid_value.present?
    end

    if alt_is_lid
      lid_value = extract_lid_digits(alt_jid)
      return lid_value if lid_value.present?
    end

    # ---- Source 2: addressingMode check + mediaUrl fallback ----
    addressing_mode = key_params['addressingMode'].to_s
    return nil unless addressing_mode == 'lid'

    # Extract LID from mediaUrl path (e.g., ".../246085134118923%40lid/audioMessage/...")
    media_url = data_params['mediaUrl'].to_s
    if media_url.present?
      match = media_url.match(%r{/(\d+)(?:%40|@)lid/}i)
      if match
        lid_value = match[1]
        return lid_value if lid_value.match?(/^\d+$/)
      end
    end

    nil
  end

  # Extract digits-only LID from a @lid JID
  # "246085134118923@lid" → "246085134118923"
  # "246085134118923:39@lid" → "246085134118923"
  def extract_lid_digits(jid)
    lid_part = jid.to_s.split('@').first
    lid_value = lid_part.split(':').first
    lid_value if lid_value.present? && lid_value.match?(/^\d+$/)
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
