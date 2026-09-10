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

    return if skip_group_message?

    # Skip broadcasts, status and newsletters
    return if contact_jid.to_s.match?(/(@broadcast|status)/)
    return if contact_jid.to_s.include?('@newsletter')

    # Skip invalid phone numbers (unless it's a LID or a group, which have no phone number)
    if contact_phone_number.blank? && !contact_jid.to_s.include?('@lid') && !is_group?
      Rails.logger.debug "[EVOLUTION_GO MSG] Invalid phone: #{contact_jid}"
      return
    end

    # Handle edited messages (both incoming and fromMe)
    if edited_message?
      handle_edited_message
      return
    end

    process_with_dedup_lock
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO MSG] Error: #{e.message}"
    Rails.logger.debug "[EVOLUTION_GO MSG] Backtrace:\n#{e.backtrace.first(5).join("\n")}"
    raise
  end

  private

  # EvoGO redelivers events, so the same message can land on two workers at once. The lock is
  # released when processing raises, because the job re-raises for Sidekiq to retry and a held
  # lock would make the retry skip the message entirely.
  def process_with_dedup_lock
    return process_message if message_id.blank?

    dedup_lock = Whatsapp::MessageDedupLock.new(message_id)
    return Rails.logger.info("[EVOLUTION_GO MSG] Duplicate prevented for #{message_id}") unless dedup_lock.acquire!

    begin
      process_message
    rescue StandardError
      dedup_lock.release!
      raise
    end
  end

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

    # A group is addressed by the chat itself. Sender names the participant who spoke, not the
    # counterpart, so resolving it here would open one conversation per member.
    return @contact_jid = group_jid if is_group?

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

  # A group is only ingested when the inbox opted in, and only when the payload actually names one:
  # IsGroup also covers communities and announcement chats, which carry no @g.us chat jid.
  def skip_group_message?
    return false unless is_group?

    !groups_enabled? || group_jid.blank?
  end

  def groups_enabled?
    ['true', true].include?(inbox.channel.provider_config&.dig('groups_enabled'))
  end

  def group_jid
    chat_jid if chat_jid.end_with?('@g.us')
  end

  # Who spoke inside the group. On an echo of our own message that is the business itself.
  def participant_jid
    return owner_jid if from_me?

    preferred_identifier(sender_jid, sender_alt_jid)
  end

  def participant_phone
    jid = participant_jid
    jid = resolve_phone_from_lid(jid) || jid unless jid.to_s.include?('@s.whatsapp.net')
    return nil unless jid.to_s.include?('@s.whatsapp.net')

    digits = jid.split('@').first
    "+#{digits}" if digits.match?(/^\d{7,15}$/)
  end

  def group_data
    @group_data ||= data_params['groupData'] || {}
  end

  # The subject of the group. EvoGO ships it inside the message on most payloads, so the API is
  # only asked when it is missing.
  def resolved_group_name
    return @resolved_group_name if defined?(@resolved_group_name)

    @resolved_group_name = group_data['Name'].presence ||
                           inbox.channel.provider_service.fetch_group_name(group_jid)
  end

  # Named after the jid while the subject is unknown. A blank name would make the builder mint a
  # random one, and "wispy-sun-4821" in the conversation list helps nobody.
  def provisional_group_name
    I18n.t('conversations.whatsapp.group_default_name', id: group_jid.split('@').first.last(6),
           locale: inbox.account.locale)
  end

  def group_display_name
    resolved_group_name.presence || provisional_group_name
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
    # If the JID is a LID, it's not a real phone number
    if jid.to_s.include?('@lid')
      @contact_phone_number = nil
    else
      phone = jid.split('@').first.split(':').first
      if phone.present? && phone.match?(/^\d{7,15}$/)
        @contact_phone_number = "+#{phone}"
      else
        @contact_phone_number = nil
      end
    end

    @contact_phone_number
  end

  def contact_source_id
    return group_jid if is_group?

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
      interactive_reply_content ||
      poll_content ||
      ''
  end

  # Button, list and template replies: the contact picked an option and its label is the
  # message. Without this they arrive as an empty bubble.
  def interactive_reply_content
    message_params.dig('buttonsResponseMessage', 'selectedDisplayText') ||
      message_params.dig('listResponseMessage', 'title') ||
      message_params.dig('templateButtonReplyMessage', 'selectedDisplayText')
  end

  def poll_content
    poll = message_params['pollCreationMessage'] || message_params['pollCreationMessageV3']
    return if poll.blank?

    options = Array(poll['options']).filter_map { |option| option['optionName'].presence }
    [poll['name'], *options.map { |option| "- #{option}" }].compact.join("\n").presence
  end

  def location_params
    message_params['locationMessage'] || message_params['liveLocationMessage']
  end

  # Reactions and protocol frames (revoke, ephemeral settings, key distribution) carry no
  # content and no media, so storing them would leave a blank bubble in the timeline.
  def renderable_message?
    return false if message_params.key?('reactionMessage')
    return false if message_params.key?('protocolMessage')

    text_content.present? || detect_media.present? || location_params.present?
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

    # Scoped to the inbox: source_id is not unique across accounts, and a global lookup would
    # let one channel rewrite another account's message.
    message = inbox.messages.find_by(source_id: original_id)
    return if message.nil?

    message.update!(content: "#{edited_text}#{I18n.t('conversations.messages.edited_suffix')}")
    Rails.logger.info "[EVOLUTION_GO MSG] Updated message #{message.id} (edited)"
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO MSG] Edit handling error: #{e.message}"
  end

  # --- Contact management ---

  def contact_attributes
    return { name: group_display_name, phone_number: nil, identifier: group_jid } if is_group?

    {
      name: from_me? ? contact_phone_number : (push_name.presence || contact_phone_number),
      phone_number: contact_phone_number,
      identifier: contact_jid
    }
  end

  def set_contact
    return set_group_contact if is_group?

    # 1. Tenta encontrar o ContactInbox já existente nesta inbox (por source_id = JID atual)
    contact_inbox = find_existing_contact_inbox

    # 2. Se não achou na inbox, mas temos um JID de telefone (@s.whatsapp.net)
    if contact_inbox.blank? && contact_jid.to_s.include?('@s.whatsapp.net')
      # Busca o contato usando a busca exata + fallback de 9º dígito
      existing_contact = find_existing_contact_by_phone
      
      # Fusão preventiva: Se achamos o contato real, mas temos um contato LID criado anteriormente, faz a mesclagem
      if existing_contact && payload_lid_source_id.present?
        lid_contact_inbox = inbox.contact_inboxes.find_by(source_id: payload_lid_source_id)
        if lid_contact_inbox && lid_contact_inbox.contact_id != existing_contact.id
          Rails.logger.info "[EVOLUTION_GO MSG] Mesclando contato LID #{lid_contact_inbox.contact_id} no contato real #{existing_contact.id}"
          ContactMergeAction.new(
            account: inbox.account,
            base_contact: existing_contact,
            mergee_contact: lid_contact_inbox.contact
          ).perform
        end
      end

      # Tenta recarregar/criar o ContactInbox após a fusão
      existing_contact ||= find_existing_contact_by_phone
      if existing_contact
        contact_inbox = inbox.contact_inboxes.find_or_create_by!(
          contact: existing_contact,
          source_id: contact_source_id
        )
      end

      # No contact carries this phone yet, but the payload names the same person twice and the
      # @lid half may already be stored from an earlier lid-only message. Without this lookup
      # the builder below mints a second contact, and the swap in step 5 promotes nothing
      # because by then it is holding the freshly created one.
      contact_inbox ||= inbox.contact_inboxes.find_by(source_id: payload_lid_source_id) if payload_lid_source_id.present?
    end

    # 3. Se ainda não achou, e é um LID, verifica se já temos o ContactInbox do LID ou mapeamento
    if contact_inbox.blank? && contact_jid.to_s.include?('@lid')
      # Busca pelo ContactInbox do LID diretamente
      contact_inbox = inbox.contact_inboxes.find_by(source_id: contact_source_id)

      # Se não achou, busca pelo mapeamento indexado
      if contact_inbox.blank?
        lid_value = extract_lid_digits(contact_jid)
        mapping = Channel::WhatsappLidMapping.find_by(lid: lid_value, inbox_id: inbox.id)
        if mapping
          contact_inbox = mapping.contact.contact_inboxes.find_by(inbox_id: inbox.id)
        end
      end
    end

    # 4. Se ainda assim não achou, cria usando o builder padrão
    contact_inbox ||= ::ContactInboxWithContactBuilder.new(
      source_id: contact_source_id,
      inbox: inbox,
      contact_attributes: contact_attributes
    ).perform

    # 5. JID Swap corrigido
    swap_lid_source_id(contact_inbox)

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact

    update_contact_name_if_needed
  end

  # A group is a chat, not a person: none of the phone and LID reconciliation above applies to it,
  # and running it would resolve the participant instead of the group.
  def set_group_contact
    contact_inbox = inbox.contact_inboxes.find_by(source_id: group_jid)
    contact_inbox ||= ::ContactInboxWithContactBuilder.new(
      source_id: group_jid,
      inbox: inbox,
      contact_attributes: contact_attributes
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact

    update_group_name_if_needed
  end

  # A group that entered before its subject was known carries the provisional name. The real one
  # replaces it as soon as it shows up, but a name the agent typed is left alone.
  def update_group_name_if_needed
    return unless @contact.name == provisional_group_name
    return if resolved_group_name.blank?

    @contact.update!(name: resolved_group_name)
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO MSG] Failed to update group name: #{e.message}"
  end

  # Promotes a contact first seen by LID to its real phone number once WhatsApp reveals it.
  def swap_lid_source_id(contact_inbox)
    return unless contact_inbox.contact.identifier.to_s.include?('@lid')
    return unless contact_jid.to_s.include?('@s.whatsapp.net')

    # (inbox_id, source_id) is unique. If the phone source_id already belongs to another
    # contact_inbox the rename raises, and the job would retry on that forever.
    if inbox.contact_inboxes.where.not(id: contact_inbox.id).exists?(source_id: contact_source_id)
      Rails.logger.warn "[EVOLUTION_GO MSG] JID Swap skipped: source_id #{contact_source_id} already taken in inbox #{inbox.id}"
      return
    end

    # identifier and phone_number are both unique per account, so another contact already holding
    # either one would make the update raise and leave the job retrying forever.
    taken = inbox.account.contacts.where.not(id: contact_inbox.contact_id)
    if taken.exists?(identifier: contact_jid) || taken.exists?(phone_number: contact_phone_number)
      Rails.logger.warn "[EVOLUTION_GO MSG] JID Swap skipped: #{contact_jid} already belongs to another contact " \
                        "in account #{inbox.account_id}"
      return
    end

    Rails.logger.info "[EVOLUTION_GO MSG] JID Swap: #{contact_inbox.source_id} → #{contact_source_id}"

    contact_inbox.update!(source_id: contact_source_id)
    contact_inbox.contact.update!(phone_number: contact_phone_number, identifier: contact_jid)
  end

  def find_existing_contact_inbox
    inbox.contact_inboxes.find_by(source_id: contact_source_id)
  end

  # Auxiliar para identificar o LID no payload
  # The JIDs that name the contact in this payload, never the business itself. On an outgoing
  # echo Sender holds our own lid and the contact is in Chat, so a lookup that scans both
  # directions at once resolves to the business number and picks the wrong contact.
  def contact_candidate_jids
    from_me? ? [chat_jid, recipient_alt_jid] : [sender_jid, sender_alt_jid]
  end

  def payload_lid_source_id
    lid_jid = contact_candidate_jids.find { |j| j.to_s.include?('@lid') }
    return nil if lid_jid.blank?

    extract_lid_digits(lid_jid)
  end

  # Auxiliar de busca com fallback para o 9º dígito brasileiro
  def find_existing_contact_by_phone
    return nil if contact_phone_number.blank?

    # 1. Busca exata
    contact = inbox.account.contacts.find_by(phone_number: contact_phone_number)
    return contact if contact.present?

    # 2. Fallback de 9º dígito (apenas para números brasileiros)
    # Formato e164: +55 + DDD (2 dígitos) + número (8 ou 9 dígitos)
    clean_phone = contact_phone_number.to_s.gsub(/^\+/, '')
    if clean_phone.start_with?('55')
      ddd = clean_phone[2, 2]
      number = clean_phone[4..-1]

      modified_phone = if clean_phone.length == 13 && number.start_with?('9')
                         # Remove o '9'
                         "+55#{ddd}#{number[1..-1]}"
                       elsif clean_phone.length == 12
                         # Adiciona o '9'
                         "+55#{ddd}9#{number}"
                       end

      if modified_phone.present?
        Rails.logger.info "[EVOLUTION_GO MSG] Tentando busca com variante do 9º dígito: #{modified_phone}"
        contact = inbox.account.contacts.find_by(phone_number: modified_phone)
        return contact if contact.present?
      end
    end

    nil
  end

  # Save LID → phone mapping. Outgoing echoes carry the pair as well — Chat holds the contact's
  # @lid and RecipientAlt its phone — and they are often the only place both halves appear.
  def save_lid_mapping_if_needed
    return if @contact.blank?
    # In a group the candidate jids name the participant, so the mapping would point their lid at
    # the group contact and hijack their own 1:1 routing.
    return if is_group?

    lid_jid = contact_candidate_jids.find { |j| j.to_s.include?('@lid') }
    phone_jid = contact_candidate_jids.find { |j| j.to_s.include?('@s.whatsapp.net') }

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
    return if from_me?
    return if is_group?
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
    # A group avatar lives behind a different endpoint; fetching it is a later slice.
    return if is_group?

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

  # Arbitrary namespace for the advisory lock below, so a contact_inbox id cannot collide
  # with a lock taken elsewhere for an unrelated record that happens to share the id.
  CONVERSATION_LOCK_NAMESPACE = 8_251

  # A message from the contact and the echo of a reply sent from the phone itself arrive as two
  # concurrent webhooks. Both looked for an open conversation, neither found one because the
  # other had not committed yet, and each created its own.
  #
  # The lock is taken on the resolved contact_inbox, never on anything read straight from the
  # payload: EvoGO addresses the same chat by phone JID in one webhook and by LID in the other,
  # so only the record this service has already resolved is a stable key. pg_advisory_xact_lock
  # waits instead of failing and is released when the transaction ends, so the second worker
  # simply finds the conversation the first one created.
  def set_conversation
    Conversation.transaction do
      Conversation.connection.execute(
        "SELECT pg_advisory_xact_lock(#{CONVERSATION_LOCK_NAMESPACE}, #{@contact_inbox.id.to_i})"
      )
      assign_conversation
    end
  end

  def assign_conversation
    # 1. Tenta buscar conversa ativa no ContactInbox específico
    @conversation = if inbox.lock_to_single_conversation
                      @contact_inbox.conversations.last
                    else
                      @contact_inbox.conversations.where.not(status: :resolved).last
                    end

    return if @conversation

    # 2. Fallback: Busca qualquer conversa ativa do CONTATO nesta INBOX (LID ou Telefone)
    active_conv = if inbox.lock_to_single_conversation
                    inbox.conversations.where(contact_id: @contact.id).last
                  else
                    inbox.conversations.where(contact_id: @contact.id).where.not(status: :resolved).last
                  end

    if active_conv.present?
      # Atualiza o contact_inbox_id para o atual para garantir que o fluxo de saída use o JID ativo correto
      active_conv.update!(contact_inbox_id: @contact_inbox.id)
      @conversation = active_conv
    else
      # 3. Cria uma nova conversa se realmente não existir nenhuma ativa
      @conversation = ::Conversation.create!(
        account_id: inbox.account_id,
        inbox_id: inbox.id,
        contact_id: @contact.id,
        contact_inbox_id: @contact_inbox.id
      )
    end
  end

  # --- Message creation ---

  def create_message
    return if message_id.present? && inbox.messages.exists?(source_id: message_id)

    unless renderable_message?
      Rails.logger.info "[EVOLUTION_GO MSG] Skipping message #{message_id} with no renderable content"
      return
    end

    @message = @conversation.messages.new(message_attributes)

    # Attachments are built on the unsaved message so the single save! below commits them in the
    # same transaction. message_created is dispatched from that commit, so the bot and every other
    # webhook consumer receive the payload with attachments already populated.
    attach_location
    attach_media

    # renderable_message? vouched for the inbound payload; this guards the result. A media message
    # whose file never materialised (blocked host, missing URL) and that carries no text would
    # otherwise persist as a blank bubble.
    if @message.content.blank? && @message.attachments.empty?
      Rails.logger.info "[EVOLUTION_GO MSG] Skipping message #{message_id}: no text and media unavailable"
      return
    end

    @message.save!
  end

  def message_attributes
    {
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      content: text_content,
      source_id: message_id,
      created_at: message_timestamp,
      content_attributes: message_content_attributes,
      message_type: from_me? ? :outgoing : :incoming,
      sender: from_me? ? @conversation.assignee : @contact
    }
  end

  # Build content_attributes hash, including in_reply_to if present.
  # The model callback ensure_in_reply_to will resolve the external_id
  # to the internal message ID automatically.
  def message_content_attributes
    attrs = {}
    attrs[:in_reply_to_external_id] = quoted_message_id if quoted_message_id.present?
    # Author of this message, so a later reply can quote it without guessing the addressing
    # mode. WhatsApp rejects a quote whose participant is in the wrong form.
    attrs[:sender_jid] = group_or_contact_sender_jid
    attrs[:group_participant] = { name: push_name, phone: participant_phone, jid: participant_jid } if is_group? && !from_me?
    attrs
  end

  # In a group contact_jid is the group, and quoting a group jid as the participant is rejected.
  def group_or_contact_sender_jid
    return owner_jid if from_me?
    return participant_jid if is_group?

    contact_jid
  end

  # Our own JID, as WhatsApp addressed it on this message.
  def owner_jid
    return sender_jid if sender_jid.present?

    phone = inbox.channel.phone_number.to_s.gsub(/^\+/, '')
    "#{phone}@s.whatsapp.net" if phone.present?
  end

  # EvoGO marks quoted messages with data.isQuoted=true and provides the original message ID
  # in data.quoted.stanzaID. Replies also carry it in the message's own contextInfo, which is
  # the only copy present on some payloads.
  def quoted_message_id
    return @quoted_message_id if defined?(@quoted_message_id)

    @quoted_message_id = data_params.dig('quoted', 'stanzaID').presence || context_info['stanzaID'].presence
  end

  # contextInfo hangs off whichever message variant is present (extendedTextMessage,
  # imageMessage, …), so it is looked up rather than addressed directly.
  def context_info
    @context_info ||= message_params.values.find { |v| v.is_a?(Hash) && v['contextInfo'].is_a?(Hash) }
                                    &.dig('contextInfo') || {}
  end

  # --- Attachment handling ---
  # EvoGO sends media differently from Evolution API:
  # - mediaUrl is at Message level (not data level)
  # - Media data is in imageMessage, audioMessage, videoMessage, documentMessage
  # - mediaUrl points to MinIO bucket

  # A location is a set of coordinates, not a file. LocationBubble only renders when the message
  # carries no text, so the place name goes on fallback_title rather than into content.
  def attach_location
    location = location_params
    return if location.blank?

    @message.attachments.new(
      account_id: @message.account_id,
      file_type: :location,
      coordinates_lat: location['degreesLatitude'],
      coordinates_long: location['degreesLongitude'],
      # A pinned location names the place and the address; a live one only carries a caption.
      fallback_title: [location['name'], location['address'], location['caption']].compact_blank.join(' - ').presence
    )
  end

  # EvoGO returns media inline as base64 and only fills mediaUrl when it has storage of its own.
  # The URL inside imageMessage/audioMessage is WhatsApp's CDN, which serves the file still
  # AES-encrypted, so it is never a usable source here. The attachment is built on the unsaved
  # message so message_created is dispatched with the file already in place.
  def attach_media
    media_payload = detect_media
    return unless media_payload

    type, data = media_payload
    file_type = map_file_type(type)
    mimetype = message_params['mimetype'] || data['mimetype']
    filename = data['fileName'] || generate_filename(type, mimetype)

    if message_params['base64'].present?
      build_attachment(file_type, StringIO.new(Base64.decode64(message_params['base64'])), filename, mimetype)
    else
      download_media(file_type, filename, mimetype)
    end
  end

  # mediaUrl points at EvoGO's own MinIO on the internal network, so allow_private_network is
  # needed to get past the SSRF IP filter for that hop.
  def download_media(file_type, filename, mimetype)
    url = message_params['mediaUrl'].presence
    return if url.blank? || media_host_blocked?(url)

    SafeFetch.fetch(url, validate_content_type: false, allow_private_network: true) do |result|
      # SafeFetch unlinks its tempfile the moment this block returns, but ActiveStorage only
      # uploads the blob in the after_commit fired by the save! below. Reading the bytes here
      # keeps the payload alive until then; without it the row commits and the upload dies with
      # Errno::ENOENT, leaving an attachment whose file was never stored.
      io = StringIO.new(result.tempfile.read)
      build_attachment(file_type, io, filename, mimetype.presence || result.content_type)
    end
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO MSG] Media fetch failed for #{message_id}: #{e.class}"
    # A caption keeps the bubble renderable, so the message is still worth saving. With nothing
    # else to show, re-raise: the dedup lock is dropped and Sidekiq retries the fetch rather
    # than persisting an empty bubble.
    raise if text_content.blank?
  end

  # allow_private_network turns off the SSRF IP filter for the MinIO hop, so when
  # EVOLUTIONGO_MEDIA_HOSTS is set it is the only thing stopping a misbehaving relay from
  # pointing mediaUrl at an internal address. Unset means no restriction (current behaviour).
  def media_host_blocked?(url)
    allowed = ENV.fetch('EVOLUTIONGO_MEDIA_HOSTS', '').split(',').map(&:strip).compact_blank
    return false if allowed.empty?

    host = URI.parse(url).host
    return false if allowed.include?(host)

    Rails.logger.warn "[EVOLUTION_GO MSG] Media host not in EVOLUTIONGO_MEDIA_HOSTS: #{host.inspect}"
    true
  rescue URI::InvalidURIError
    true
  end

  def build_attachment(file_type, io, filename, content_type)
    attachment = @message.attachments.new(account_id: @message.account_id, file_type: file_type)
    attachment.file.attach(
      io: io,
      filename: filename,
      content_type: content_type.presence || 'application/octet-stream'
    )
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
