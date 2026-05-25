# Service to process incoming messages from Evolution GO API (WhatsApp Lite)
# Payload structure differs from standard Evolution API:
#
# {
#   "data": {
#     "Info": {
#       "ID": "message_id",
#       "IsFromMe": false,
#       "IsGroup": false,
#       "Sender": "number@s.whatsapp.net",
#       "SenderAlt": "lid@lid",
#       "PushName": "Contact Name",
#       "Chat": "number@s.whatsapp.net",
#       "Timestamp": "2026-04-21T20:38:16-03:00",
#       "Type": "text" | "media",
#       "MediaType": "" | "image" | "ptt" | "video" | "document",
#       "Edit": "" | "1"
#     },
#     "Message": { ... },
#     "IsEdit": false
#   },
#   "event": "Message",
#   "instanceId": "...",
#   "instanceName": "...",
#   "instanceToken": "..."
# }

class Whatsapp::IncomingMessageEvolutionGoService
  pattr_initialize [:inbox!, :params!]

  def perform
    @normalized_params = normalize_params(params)

    return if data_params.blank?
    return if info_params.blank?

    # Skip groups, broadcasts, status
    return if contact_jid.to_s.match?(/(@broadcast|status)/)
    return if is_group?

    # Skip invalid phone numbers
    if contact_phone_number.blank?
      Rails.logger.debug "[EVOLUTION_GO MSG] Invalid phone: #{contact_jid}"
      return
    end

    # Handle edited messages (both incoming and fromMe)
    if edited_message?
      handle_edited_message
      return
    end

    # Distributed lock for idempotency
    lock_key = "evogo:msg:#{message_id}"

    if defined?(Redis::Lock)
      begin
        Redis::Lock.new(lock_key, expiration: 30, timeout: 0.1).lock do
          process_message
        end
      rescue Redis::Lock::LockError
        Rails.logger.info "[EVOLUTION_GO MSG] Duplicate prevented for #{message_id}"
      end
    else
      process_message
    end
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO MSG] Error: #{e.message}"
    Rails.logger.debug "[EVOLUTION_GO MSG] Backtrace:\n#{e.backtrace.first(5).join("\n")}"
    raise
  end

  private

  def process_message
    direction = from_me? ? 'outgoing' : 'incoming'
    Rails.logger.info "[EVOLUTION_GO MSG] #{direction} | #{contact_phone_number} | #{message_type} | " \
                      "Sender=#{sender_jid} SenderAlt=#{sender_alt_jid} Chat=#{chat_jid} → JID=#{contact_jid}"

    set_contact
    set_contact_avatar
    save_lid_mapping_if_needed
    set_conversation
    create_message
  end

  # --- Param accessors ---

  def normalize_params(p)
    JSON.parse(p.to_json)
  rescue JSON::GeneratorError, JSON::ParserError
    p.to_h.transform_keys(&:to_s)
  end

  def data_params
    @data_params ||= @normalized_params['data'] || {}
  end

  def info_params
    @info_params ||= data_params['Info'] || {}
  end

  def message_params
    @message_params ||= data_params['Message'] || {}
  end

  # --- Message identifiers ---

  def message_id
    info_params['ID']
  end

  def sender_jid
    info_params['Sender'].to_s.gsub(/:[^@]+/, '')
  end

  def sender_alt_jid
    info_params['SenderAlt'].to_s.gsub(/:[^@]+/, '')
  end

  def recipient_alt_jid
    info_params['RecipientAlt'].to_s.gsub(/:[^@]+/, '')
  end

  def chat_jid
    info_params['Chat'].to_s.gsub(/:[^@]+/, '')
  end

  # The JID that identifies the CONTACT (not the owner).
  # For incoming messages: Sender/SenderAlt/Chat are analyzed to find the real number.
  def contact_jid
    return @contact_jid if defined?(@contact_jid)

    @contact_jid = if from_me?
                     # fromMe: Sender is our own LID, the contact is in RecipientAlt
                     jid = recipient_alt_jid
                     # Fallback to Chat if RecipientAlt is blank or @lid
                     if jid.blank? || !jid.include?('@s.whatsapp.net')
                       jid = chat_jid
                     end
                     # If still @lid, try to resolve via LID mapping table
                     if jid.present? && !jid.include?('@s.whatsapp.net')
                       jid = resolve_phone_from_lid(jid) || jid
                     end
                     jid
                   else
                     # Incoming: prioritize @s.whatsapp.net over @lid from Sender/SenderAlt
                     jid = preferred_identifier(sender_jid, sender_alt_jid)

                     # Fallback to Chat field when Sender/SenderAlt are both @lid
                     if jid.blank? || !jid.include?('@s.whatsapp.net')
                       jid = chat_jid if chat_jid.to_s.include?('@s.whatsapp.net')
                     end

                     # Last resort: resolve via LID mapping table
                     if jid.present? && !jid.include?('@s.whatsapp.net')
                       jid = resolve_phone_from_lid(jid) || jid
                     end

                     jid
                   end
  end

  # Prioritize @s.whatsapp.net over @lid
  def preferred_identifier(jid1, jid2)
    return jid1 if jid1.to_s.include?('@s.whatsapp.net')
    return jid2 if jid2.to_s.include?('@s.whatsapp.net')

    # Fallback to lid if no real number found
    jid1.presence || jid2
  end

  def push_name
    info_params['PushName']
  end

  def from_me?
    info_params['IsFromMe'] == true
  end

  def is_group?
    info_params['IsGroup'] == true
  end

  def message_type
    info_params['Type'].to_s
  end

  def media_type
    info_params['MediaType'].to_s
  end

  def message_timestamp
    ts = info_params['Timestamp']
    return Time.current if ts.blank?

    Time.parse(ts)
  rescue ArgumentError
    Time.current
  end

  def edited_message?
    info_params['Edit'].to_s == '1' || data_params['IsEdit'] == true
  end

  # --- Phone number extraction ---

  def contact_phone_number
    return @contact_phone_number if defined?(@contact_phone_number)

    jid = contact_jid
    phone = jid.split('@').first.split(':').first

    if phone.present? && phone.match?(/^\d{7,15}$/)
      @contact_phone_number = "+#{phone}"
    else
      @contact_phone_number = nil
    end

    @contact_phone_number
  end

  def contact_source_id
    id = contact_jid.split('@').first
    id.to_s.include?(':') ? id.split(':').first : id
  end

  # --- Text extraction ---

  def text_content
    # Regular text
    message_params['conversation'] ||
      # Extended text (with link preview)
      message_params.dig('extendedTextMessage', 'text') ||
      # Image/video/document caption
      message_params.dig('imageMessage', 'caption') ||
      message_params.dig('videoMessage', 'caption') ||
      message_params.dig('documentMessage', 'caption') ||
      ''
  end

  # --- Edited message handling ---

  def handle_edited_message
    # The edited content is in protocolMessage.editedMessage.conversation
    edited_text = message_params.dig('protocolMessage', 'editedMessage', 'conversation') ||
                  message_params.dig('protocolMessage', 'editedMessage', 'extendedTextMessage', 'text')

    return if edited_text.blank?

    # Find original message by the key.ID in protocolMessage
    original_id = message_params.dig('protocolMessage', 'key', 'ID')
    return if original_id.blank?

    message = Message.find_by(source_id: original_id)
    return if message.nil?

    message.update!(content: "#{edited_text}\n\n_(Editada)_")
    Rails.logger.info "[EVOLUTION_GO MSG] Updated message #{message.id} (edited)"
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO MSG] Edit handling error: #{e.message}"
  end

  # --- Contact management ---

  def contact_attributes
    {
      name: from_me? ? contact_phone_number : (push_name.presence || contact_phone_number),
      phone_number: contact_phone_number,
      identifier: contact_jid
    }
  end

  def set_contact
    # 1. Tenta encontrar o ContactInbox já existente nesta inbox (por source_id = JID atual)
    contact_inbox = find_existing_contact_inbox

    # 2. Se não achou na inbox, mas temos um JID de telefone (@s.whatsapp.net), 
    # busca se esse contato já existe em OUTRA inbox da conta para evitar duplicidade
    if contact_inbox.blank? && contact_jid.to_s.include?('@s.whatsapp.net')
      existing_contact = inbox.account.contacts.find_by(phone_number: contact_phone_number)
      if existing_contact
        contact_inbox = inbox.contact_inboxes.create!(
          contact: existing_contact,
          source_id: contact_source_id
        )
      end
    end

    # 3. Se ainda não achou, e é um LID, verifica se já mapeamos esse LID para algum telefone anteriormente
    if contact_inbox.blank? && contact_jid.to_s.include?('@lid')
      lid_value = extract_lid_digits(contact_jid)
      mapping = Channel::WhatsappLidMapping.find_by(lid: lid_value, inbox_id: inbox.id)
      if mapping
        contact_inbox = mapping.contact.contact_inboxes.find_by(inbox_id: inbox.id)
      end
    end

    # 4. Se ainda assim não achou, usa o builder padrão (que criará um novo se não achar por telefone)
    contact_inbox ||= ::ContactInboxWithContactBuilder.new(
      source_id: contact_source_id,
      inbox: inbox,
      contact_attributes: contact_attributes
    ).perform

    # 5. JID Swap: Se o contato foi achado/criado via LID, mas agora temos o Telefone real, 
    # atualiza o source_id para o telefone para que as próximas mensagens batam direto.
    if contact_inbox.source_id.include?('lid') && contact_jid.to_s.include?('@s.whatsapp.net')
      Rails.logger.info "[EVOLUTION_GO MSG] JID Swap: Updating source_id from #{contact_inbox.source_id} to #{contact_source_id}"
      contact_inbox.update!(source_id: contact_source_id)
    end

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact

    update_contact_name_if_needed
  end

  def find_existing_contact_inbox
    inbox.contact_inboxes.find_by(source_id: contact_source_id)
  end

  # Save LID → phone mapping when processing incoming messages.
  def save_lid_mapping_if_needed
    return if from_me?
    return if @contact.blank?

    # Identify which JID is the LID and which is the Phone (Sender or SenderAlt)
    lid_jid = [sender_jid, sender_alt_jid].find { |j| j.to_s.include?('@lid') }
    phone_jid = [sender_jid, sender_alt_jid].find { |j| j.to_s.include?('@s.whatsapp.net') }

    lid_value = extract_lid_digits(lid_jid)
    return if lid_value.blank?

    # Prefer phone from the payload if available, otherwise from contact record
    phone = (phone_jid&.split('@')&.first || @contact.phone_number.to_s.gsub(/^\+/, ''))
    return if phone.blank?

    Channel::WhatsappLidMapping.create_or_update_mapping!(
      lid: lid_value,
      phone_number: phone,
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: @contact.id
    )
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO MSG] LID mapping save failed: #{e.message}"
  end

  # Resolve a @lid JID to a phone@s.whatsapp.net JID via the mapping table
  def resolve_phone_from_lid(lid_jid)
    lid_value = extract_lid_digits(lid_jid)
    return nil if lid_value.blank?

    mapping = Channel::WhatsappLidMapping.resolve_contact(inbox.account_id, lid_value)
    return nil unless mapping

    phone = mapping[:phone_number].to_s.gsub(/^\+/, '')
    Rails.logger.info "[EVOLUTION_GO MSG] LID #{lid_value} resolved to phone #{phone}"
    "#{phone}@s.whatsapp.net"
  end

  # Extract digits-only LID from a @lid JID
  # "27041265119351@lid" → "27041265119351"
  # "27041265119351:58@lid" → "27041265119351"
  def extract_lid_digits(jid)
    return nil unless jid.to_s.include?('@lid')

    lid_part = jid.split('@').first
    lid_value = lid_part.split(':').first
    lid_value if lid_value.present? && lid_value.match?(/^\d+$/)
  end

  def update_contact_name_if_needed
    return if push_name.blank?
    return unless @contact.present?

    current_name = @contact.name.to_s
    is_phone_name = current_name.match?(/\A\+?\d+\z/) || current_name == contact_phone_number

    return unless is_phone_name

    @contact.update!(name: push_name)
    Rails.logger.info "[EVOLUTION_GO MSG] Updated contact #{@contact.id} name: '#{current_name}' → '#{push_name}'"
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO MSG] Failed to update contact name: #{e.message}"
  end

  def set_contact_avatar
    return if @contact.blank?
    return if @contact.avatar.attached?

    Rails.logger.info "[EVOLUTION_GO MSG] Scheduling avatar fetch for Contact #{@contact.id} (#{contact_jid})"

    Webhooks::EvolutionGoContactAvatarJob.perform_later(
      @contact.id,
      inbox.channel.id,
      contact_jid
    )
  rescue StandardError => e
    Rails.logger.warn "[EVOLUTION_GO MSG] Avatar scheduling failed: #{e.message}"
  end

  # --- Conversation management ---

  def set_conversation
    @conversation = if inbox.lock_to_single_conversation
                      @contact_inbox.conversations.last
                    else
                      @contact_inbox.conversations.where.not(status: :resolved).last
                    end

    return if @conversation

    @conversation = ::Conversation.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id
    )
  end

  # --- Message creation ---

  def create_message
    return if message_id.present? && inbox.messages.exists?(source_id: message_id)

    attrs = {
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      content: text_content,
      source_id: message_id,
      created_at: message_timestamp,
      content_attributes: message_content_attributes
    }

    if from_me?
      attrs[:message_type] = :outgoing
      attrs[:sender] = @conversation.assignee
    else
      attrs[:message_type] = :incoming
      attrs[:sender] = @contact
    end

    @message = @conversation.messages.build(attrs)

    process_attachments_inline
    @message.save!
  end

  # Build content_attributes hash, including in_reply_to if present.
  # The model callback ensure_in_reply_to will resolve the external_id
  # to the internal message ID automatically.
  def message_content_attributes
    attrs = {}
    attrs[:in_reply_to_external_id] = quoted_message_id if quoted_message_id.present?
    attrs
  end

  # EvoGO marks quoted messages with data.isQuoted=true and provides
  # the original message ID in data.quoted.stanzaID.
  # Fallback: also check contextInfo.stanzaID inside the message payload.
  def quoted_message_id
    return @quoted_message_id if defined?(@quoted_message_id)

    @quoted_message_id = data_params.dig('quoted', 'stanzaID')
  end

  # --- Attachment handling ---
  # EvoGO sends media differently from Evolution API:
  # - mediaUrl is at Message level (not data level)
  # - Media data is in imageMessage, audioMessage, videoMessage, documentMessage
  # - mediaUrl points to MinIO bucket

  def process_attachments_inline
    media_payload = detect_media
    return unless media_payload

    type, data = media_payload

    # Get the mediaUrl from Message level (EvoGO specific)
    media_url = message_params['mediaUrl']
    mimetype = message_params['mimetype'] || data['mimetype']
    filename = data['fileName'] || generate_filename(type, mimetype)

    # Prefer MinIO URL (mediaUrl) over WhatsApp CDN (data URL)
    url = media_url.presence || data['URL'] || data['url']

    return if url.blank?

    Rails.logger.info "[EVOLUTION_GO MSG] Processing #{type} attachment from URL"

    begin
      io = URI.open(url, open_timeout: 10, read_timeout: 30)

      @message.attachments.new(
        account_id: @message.account_id,
        file_type: map_file_type(type),
        file: {
          io: io,
          filename: filename,
          content_type: mimetype || 'application/octet-stream'
        }
      )

      Rails.logger.info "[EVOLUTION_GO MSG] ✅ Attachment prepared (type: #{type}, mime: #{mimetype})"
    rescue StandardError => e
      Rails.logger.error "[EVOLUTION_GO MSG] ⚠️ Attachment failed (non-blocking): #{e.message}"
    end
  end

  def detect_media
    return [:image, message_params['imageMessage']] if message_params['imageMessage'].present?
    return [:audio, message_params['audioMessage']] if message_params['audioMessage'].present?
    return [:video, message_params['videoMessage']] if message_params['videoMessage'].present?
    return [:file, message_params['documentMessage']] if message_params['documentMessage'].present?
    return [:sticker, message_params['stickerMessage']] if message_params['stickerMessage'].present?

    nil
  end

  def map_file_type(type)
    case type.to_s
    when 'image', 'sticker' then :image
    when 'audio' then :audio
    when 'video' then :video
    else :file
    end
  end

  def generate_filename(type, mimetype)
    ext = case mimetype.to_s
          when /jpeg/, /jpg/ then 'jpg'
          when /png/ then 'png'
          when /gif/ then 'gif'
          when /webp/ then 'webp'
          when /mp4/ then 'mp4'
          when /ogg/, /opus/ then 'ogg'
          when /mp3/ then 'mp3'
          when /pdf/ then 'pdf'
          else 'bin'
          end

    "#{type}_#{Time.current.to_i}.#{ext}"
  end
end
