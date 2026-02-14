class Whatsapp::UpdateMessageEvolutionService
  pattr_initialize [:inbox!, :params!]

  def perform
    @normalized_params = normalize_params(params)
    
    # Handle edited messages (text update)
    if edited_message_data.present?
      handle_edited_message
      return
    end

    # Handle DELIVERY_ACK for fromMe messages - potential media recovery
    # Strategy: docs/example/incoming_messages.md
    # When media (audio, image, document) is sent directly from the phone,
    # only messages.update with DELIVERY_ACK arrives (no messages.upsert).
    # We detect this and fetch the media via getBase64FromMediaMessage.
    #
    # IMPORTANT: Multiple DELIVERY_ACK webhooks arrive for the same keyId with
    # different JID formats (e.g., "60224685752462:27@lid" vs "60224685752462@lid").
    # We use a Redis distributed lock keyed by keyId to ensure only ONE webhook
    # processes the media recovery for a given keyId.
    if delivery_ack? && from_me?
      handle_media_recovery_with_lock
      return
    end

  rescue StandardError => e
    Rails.logger.error "[EVOLUTION MSG UPDATE] Error: #{e.message}"
    Rails.logger.debug "[EVOLUTION MSG UPDATE] Backtrace:\n#{e.backtrace&.first(5)&.join("\n")}"
  end

  private

  def normalize_params(p)
    JSON.parse(p.to_json)
  rescue JSON::GeneratorError, JSON::ParserError
    p.to_h.transform_keys(&:to_s)
  end

  def data_params
    @data_params ||= @normalized_params['data'] || {}
  end

  def key_id
    @key_id ||= data_params['keyId'] || data_params.dig('key', 'id')
  end

  def remote_jid
    @remote_jid ||= data_params['remoteJid'] || data_params.dig('key', 'remoteJid') || ''
  end

  def status
    @status ||= data_params['status'].to_s
  end

  def from_me?
    data_params['fromMe'] == true
  end

  def delivery_ack?
    status == 'DELIVERY_ACK'
  end

  def message_object
    @message_object ||= data_params['message'] || {}
  end

  def edited_message_data
    @edited_message_data ||= message_object.dig('editedMessage', 'message')
  end

  def new_text_content
    return '' unless edited_message_data

    edited_message_data['conversation'] || 
    edited_message_data.dig('extendedTextMessage', 'text') ||
    edited_message_data.dig('protocolMessage', 'editedMessage', 'conversation') ||
    ''
  end

  # ---- Edited Message Handling ----

  def handle_edited_message
    message = Message.find_by(source_id: key_id)
    return if message.nil?

    message.update!(content: "#{new_text_content}\n\n_(Editada)_")
    Rails.logger.info "[EVOLUTION MSG] Updated message #{message.id}"
  end

  # ---- Media Recovery for fromMe messages ----
  # Strategy: docs/example/incoming_messages.md
  #
  # When the user sends media (audio, image, doc) directly from the phone,
  # only a messages.update with DELIVERY_ACK arrives (no messages.upsert).
  #
  # The DELIVERY_ACK payload contains a remoteJid that can be:
  #   - "5527998999017@s.whatsapp.net" → real phone number (direct lookup)
  #   - "27041265119351@lid" or "27041265119351:58@lid" → internal WhatsApp LID (needs mapping)
  #
  # Resolution strategy for finding the correct contact/conversation:
  #   1. If remoteJid is @s.whatsapp.net → find contact by phone number
  #   2. If remoteJid is @lid → lookup via channel_whatsapp_lid_mappings table
  #   After resolution, save the LID→Contact mapping in the lid_mappings table for future lookups

  # Wraps handle_media_recovery in a Redis distributed lock keyed by keyId.
  # This is the primary deduplication mechanism:
  #   - Multiple DELIVERY_ACK webhooks arrive for the SAME keyId with different JID formats
  #     (e.g., "60224685752462:27@lid" and "60224685752462@lid")
  #   - Without the lock, both could pass the Message.exists? check and create duplicates
  #   - The lock ensures only ONE job processes a given keyId at a time
  #   - TTL of 30s covers: API call (~1s) + contact resolution + S3 upload + DB writes
  def handle_media_recovery_with_lock
    lock_key = "evol:media_recovery:#{key_id}"
    lock_manager = Redis::LockManager.new

    if lock_manager.lock(lock_key, 30.seconds)
      begin
        handle_media_recovery
      ensure
        lock_manager.unlock(lock_key)
      end
    else
      Rails.logger.info "[EVOLUTION MEDIA RECOVERY] 🔒 Lock not acquired for keyId: #{key_id}, " \
                        "another worker is already processing this media. Skipping."
    end
  end

  def handle_media_recovery
    Rails.logger.info "[EVOLUTION MEDIA RECOVERY] DELIVERY_ACK fromMe for keyId: #{key_id}, remoteJid: #{remote_jid}"

    # First, check if the message already exists (from a previous messages.upsert or a parallel webhook)
    existing_messages = Message.where(source_id: key_id)
    existing_message = existing_messages.first

    if existing_message
      # ---- Opportunistic LID mapping ----
      # Every DELIVERY_ACK with @lid that matches an existing message is a chance
      # to populate the LID→Contact mapping table. This is critical because text
      # message DELIVERY_ACKs arrive BEFORE audio DELIVERY_ACKs, so by the time
      # the audio arrives, the mapping already exists.
      save_lid_mapping_from_existing_message(existing_message) if lid_jid?

      # Message exists - check if it needs media
      if existing_message.attachments.any?
        Rails.logger.info "[EVOLUTION MEDIA RECOVERY] Message #{existing_message.id} already has attachments, skipping"
        return
      end

      # Message exists but no attachments - it might be text (normal) or media that failed to attach
      # Only try to fetch media if message content is blank (likely a failed media)
      if existing_message.content.present? && existing_message.content.strip.length > 0
        Rails.logger.info "[EVOLUTION MEDIA RECOVERY] Message #{existing_message.id} has text content, likely not media. Skipping."
        return
      end

      Rails.logger.info "[EVOLUTION MEDIA RECOVERY] Message #{existing_message.id} has no attachments and no text, fetching media"
      schedule_media_fetch(existing_message.id)
    else
      # Message doesn't exist — this is the scenario from incoming_messages.md:
      # Media sent directly from the phone, no messages.upsert was received.
      #
      # Step 1: Call Evolution API to verify it IS media (getBase64FromMediaMessage)
      # Step 2: Find/resolve contact and conversation using remoteJid (@lid or phone)
      # Step 3: Create the message and attach the media
      Rails.logger.info "[EVOLUTION MEDIA RECOVERY] Message not found for keyId: #{key_id}, checking if it's media..."
      fetch_and_create_media_message
    end
  end

  # ---- Step 1: Fetch media from Evolution API ----
  # Only creates the message if the API confirms it's media content.
  # Text messages return 400 "The message is not of the media type" and are skipped.
  def fetch_and_create_media_message
    channel = inbox.channel
    return unless channel

    # DEDUPLICATION (early check): If the message already exists, skip immediately.
    # This avoids unnecessary API calls to getBase64FromMediaMessage.
    # Note: The Redis lock (handle_media_recovery_with_lock) is the PRIMARY protection.
    # This check is a fast-path optimization for cases where the message was already
    # created by a messages.upsert event (not a competing DELIVERY_ACK).
    if Message.exists?(source_id: key_id)
      Rails.logger.info "[EVOLUTION MEDIA RECOVERY] Message with source_id #{key_id} already exists, skipping"
      return
    end

    # Call Evolution API: getBase64FromMediaMessage
    service = Whatsapp::Providers::EvolutionService.new(whatsapp_channel: channel)
    media_response = service.get_base64_from_media_message(key_id)

    unless media_response
      Rails.logger.info "[EVOLUTION MEDIA RECOVERY] No media for keyId: #{key_id}, skipping (text-only or not found)"
      return
    end

    # Extract and validate media data
    media_data = extract_media_data_inline(media_response)

    unless media_data[:base64].present?
      Rails.logger.info "[EVOLUTION MEDIA RECOVERY] No base64 in response for keyId: #{key_id}, skipping"
      return
    end

    Rails.logger.info "[EVOLUTION MEDIA RECOVERY] ✅ Media confirmed! Type: #{media_data[:mimetype]}"

    # ---- Step 2: Find the correct contact and conversation ----
    contact_and_conversation = resolve_contact_and_conversation
    return unless contact_and_conversation

    contact = contact_and_conversation[:contact]
    conversation = contact_and_conversation[:conversation]

    # ---- Step 3: Create the message (with atomic deduplication) ----
    # DEDUPLICATION (atomic check-and-create): Re-check IMMEDIATELY before create.
    # This is the final defense layer. Even though the Redis lock should prevent
    # concurrent processing, this protects against edge cases where:
    #   - The lock expired (TTL reached) before processing completed
    #   - A messages.upsert event created the message while we were fetching media
    if Message.exists?(source_id: key_id)
      Rails.logger.info "[EVOLUTION MEDIA RECOVERY] Message with source_id #{key_id} created while resolving contact, skipping"
      return
    end

    message = conversation.messages.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      content: '', # Content is the media itself
      message_type: :outgoing,
      source_id: key_id,
      sender: conversation.assignee
    )

    Rails.logger.info "[EVOLUTION MEDIA RECOVERY] Created outgoing message #{message.id} in conversation #{conversation.id}"

    # ---- Step 4: Attach the media directly ----
    attach_media_directly(message, media_data)

    # ---- Step 5: Save LID mapping for future lookups ----
    save_lid_mapping(contact) if lid_jid?

  rescue ActiveRecord::RecordNotUnique
    # Another thread beat us to it — this is fine
    Rails.logger.info "[EVOLUTION MEDIA RECOVERY] Duplicate source_id #{key_id} caught by DB constraint, skipping"
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION MEDIA RECOVERY] Failed: #{e.message}"
    Rails.logger.debug "[EVOLUTION MEDIA RECOVERY] Backtrace:\n#{e.backtrace&.first(5)&.join("\n")}"
  end

  def schedule_media_fetch(message_id)
    channel = inbox.channel
    return unless channel

    Webhooks::EvolutionFetchMediaJob.perform_later(
      message_id,
      channel.id,
      key_id
    )

    Rails.logger.info "[EVOLUTION MEDIA RECOVERY] Media fetch scheduled for Message #{message_id}, keyId: #{key_id}"
  end

  # ---- Contact & Conversation Resolution ----
  # Uses 3 strategies in cascade to find the correct contact and conversation.
  # Returns { contact:, conversation: } or nil.

  def resolve_contact_and_conversation
    jid = remote_jid.to_s
    Rails.logger.info "[EVOLUTION MEDIA RECOVERY] Resolving contact for JID: #{jid}"

    # Strategy 1: @s.whatsapp.net → find by phone number (direct lookup)
    if phone_jid?
      result = resolve_by_phone(jid)
      return result if result
    end

    # Strategy 2: @lid → lookup via channel_whatsapp_lid_mappings table
    if lid_jid?
      result = resolve_by_lid(jid)
      return result if result
    end

    # NO FALLBACK: We intentionally do NOT use a "most recent conversation" fallback.
    # When the LID is unknown, it's better to skip than to associate the media
    # with the wrong contact's conversation. The next webhook for this keyId
    # may arrive with a @s.whatsapp.net JID that can be resolved by phone.
    Rails.logger.warn "[EVOLUTION MEDIA RECOVERY] No contact/conversation found for JID: #{jid}. " \
                      "Skipping — another webhook with a phone JID may resolve this."
    nil
  end

  # Strategy 1: Resolve by phone number from @s.whatsapp.net JID
  def resolve_by_phone(jid)
    phone = extract_phone_from_jid(jid)
    return nil if phone.blank?

    source_id = phone.gsub(/\D/, '')

    # Try by ContactInbox source_id
    contact_inbox = ContactInbox.find_by(inbox_id: inbox.id, source_id: source_id)
    if contact_inbox
      conversation = find_active_conversation(contact_inbox)
      if conversation
        Rails.logger.info "[EVOLUTION MEDIA RECOVERY] [Strategy 1] Found by phone source_id: #{source_id} → Conversation #{conversation.id}"
        return { contact: contact_inbox.contact, conversation: conversation }
      end
    end

    # Try by Contact phone_number
    phone_with_plus = "+#{phone}"
    contact = Contact.where(account_id: inbox.account_id, phone_number: phone_with_plus).first
    if contact
      contact_inbox = ContactInbox.find_by(inbox_id: inbox.id, contact_id: contact.id)
      if contact_inbox
        conversation = find_active_conversation(contact_inbox)
        if conversation
          Rails.logger.info "[EVOLUTION MEDIA RECOVERY] [Strategy 1] Found by phone: #{phone_with_plus} → Conversation #{conversation.id}"
          return { contact: contact, conversation: conversation }
        end
      end
    end

    nil
  end

  # Strategy 2: Resolve by LID using the channel_whatsapp_lid_mappings table
  # Fast indexed lookup instead of JSONB search
  def resolve_by_lid(jid)
    lid_value = extract_lid_from_jid(jid)
    return nil if lid_value.blank?

    # Lookup in the dedicated LID mapping table (indexed, O(1))
    mapping = Channel::WhatsappLidMapping.find_by(
      account_id: inbox.account_id,
      lid: lid_value
    )

    if mapping
      contact = mapping.contact
      contact_inbox = ContactInbox.find_by(inbox_id: inbox.id, contact_id: contact.id)
      if contact_inbox
        conversation = find_active_conversation(contact_inbox)
        if conversation
          Rails.logger.info "[EVOLUTION MEDIA RECOVERY] [Strategy 2] Found by LID mapping: #{lid_value} → Contact #{contact.id} → Conversation #{conversation.id}"
          return { contact: contact, conversation: conversation }
        end
      end
    end

    # Fallback: check legacy additional_attributes for backward compatibility
    # This handles LIDs that were saved before the mapping table existed
    contact = Contact.where(account_id: inbox.account_id)
                     .where(
                       "additional_attributes->>'whatsapp_lid' = :lid " \
                       "OR additional_attributes->'whatsapp_lids' @> :lid_json",
                       lid: lid_value,
                       lid_json: [lid_value].to_json
                     )
                     .first

    if contact
      contact_inbox = ContactInbox.find_by(inbox_id: inbox.id, contact_id: contact.id)
      if contact_inbox
        conversation = find_active_conversation(contact_inbox)
        if conversation
          Rails.logger.info "[EVOLUTION MEDIA RECOVERY] [Strategy 2] Found by legacy LID attr: #{lid_value} → Contact #{contact.id} → Conversation #{conversation.id}"
          # Migrate this legacy mapping to the new table
          save_lid_mapping(contact)
          return { contact: contact, conversation: conversation }
        end
      end
    end

    Rails.logger.info "[EVOLUTION MEDIA RECOVERY] [Strategy 2] No contact found for LID: #{lid_value}"
    nil
  end

  # Strategy 3: REMOVED — Fallback was routing media to wrong conversations.
  # Previously, this picked the most recent active conversation in the inbox,
  # which caused audio/image messages to be associated with the wrong contact.
  # Now, if Strategy 1 and 2 fail, we return nil and skip the message.
  # The same keyId will likely arrive again with a resolvable JID format.

  # ---- LID Mapping Persistence ----
  # Save the LID→Contact mapping in the dedicated channel_whatsapp_lid_mappings table.
  # This is called AFTER a successful resolution, so next time this LID
  # appears, Strategy 2 will find it directly via indexed lookup.

  def save_lid_mapping(contact)
    lid_value = extract_lid_from_jid(remote_jid)
    return if lid_value.blank?
    return if contact.blank?

    phone = contact.phone_number
    return if phone.blank?

    Channel::WhatsappLidMapping.create_or_update_mapping!(
      lid: lid_value,
      phone_number: phone,
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: contact.id
    )

    Rails.logger.info "[EVOLUTION MEDIA RECOVERY] 💾 Saved LID mapping: #{lid_value} → Contact #{contact.id} (#{phone})"
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION MEDIA RECOVERY] Failed to save LID mapping: #{e.message}"
  end

  # Save LID mapping using data from an existing message.
  # Called during DELIVERY_ACK processing when the message already exists
  # (e.g., text messages created via messages.upsert). This populates the
  # mapping table opportunistically, so the LID→Contact link is ready
  # before any audio DELIVERY_ACK arrives.
  def save_lid_mapping_from_existing_message(message)
    lid_value = extract_lid_from_jid(remote_jid)
    return if lid_value.blank?

    # Extract contact from the message's conversation
    conversation = message.conversation
    return unless conversation

    contact_inbox = conversation.contact_inbox
    return unless contact_inbox

    contact = contact_inbox.contact
    return unless contact

    phone = contact.phone_number
    return if phone.blank?

    Channel::WhatsappLidMapping.create_or_update_mapping!(
      lid: lid_value,
      phone_number: phone,
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: contact.id
    )

    Rails.logger.info "[EVOLUTION MEDIA RECOVERY] 💾 Opportunistic LID mapping from msg #{message.id}: #{lid_value} → Contact #{contact.id} (#{phone})"
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION MEDIA RECOVERY] Failed to save opportunistic LID mapping: #{e.message}"
  end

  # ---- JID Helpers ----

  def phone_jid?
    remote_jid.to_s.include?('@s.whatsapp.net')
  end

  def lid_jid?
    remote_jid.to_s.include?('@lid')
  end

  # Extract pure phone digits from @s.whatsapp.net JID
  # "5527998999017@s.whatsapp.net" → "5527998999017"
  def extract_phone_from_jid(jid)
    local_part = jid.to_s.split('@').first
    phone = local_part.split(':').first # Strip device identifier if present
    phone if phone.present? && phone.match?(/^\d{7,15}$/)
  end

  # Extract LID identifier (digits only) from @lid JID
  # "27041265119351@lid" → "27041265119351"
  # "27041265119351:58@lid" → "27041265119351"
  def extract_lid_from_jid(jid)
    local_part = jid.to_s.split('@').first
    lid = local_part.split(':').first # Strip device suffix
    lid if lid.present? && lid.match?(/^\d+$/)
  end

  def find_active_conversation(contact_inbox)
    if inbox.lock_to_single_conversation
      contact_inbox.conversations.last
    else
      contact_inbox.conversations.where.not(status: :resolved).last
    end
  end

  # ---- Media Attachment ----

  def attach_media_directly(message, media_data)
    base64_data = media_data[:base64]
    mimetype = media_data[:mimetype] || 'application/octet-stream'
    filename = media_data[:fileName] || generate_media_filename(mimetype)

    # Remove data URI prefix if present
    base64_clean = base64_data.sub(%r{^data:.*?;base64,}, '')
    decoded = Base64.decode64(base64_clean)

    file_type = determine_media_file_type(mimetype)

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

    # Touch message to trigger ActionCable broadcast
    message.attachments.reload
    message.touch
    message.save!

    Rails.logger.info "[EVOLUTION MEDIA RECOVERY] ✅ Attachment #{attachment.id} saved (type: #{file_type}, mime: #{mimetype})"
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION MEDIA RECOVERY] Failed to attach media: #{e.message}"
  end

  # ---- Media Data Helpers ----

  def extract_media_data_inline(response)
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

  def determine_media_file_type(mimetype)
    case mimetype.to_s
    when /image/ then :image
    when /audio/ then :audio
    when /video/ then :video
    else :file
    end
  end

  def generate_media_filename(mimetype)
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
