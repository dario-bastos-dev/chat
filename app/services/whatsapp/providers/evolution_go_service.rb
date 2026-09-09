class Whatsapp::Providers::EvolutionGoService < Whatsapp::Providers::BaseService
  # EvolutionGO uses a different authentication model:
  # - Global token (EVOLUTIONGO_API_TOKEN) for creating instances
  # - Instance token (stored in provider_config) for all other operations

  SUBSCRIBED_EVENTS = %w[MESSAGE CONNECTION READ_RECEIPT].freeze
  # Attachment types WhatsApp renders with a caption.
  CAPTIONABLE_TYPES = %w[image video file].freeze
  # WhatsApp renders up to three options as buttons; past that it has to be a list.
  MAX_REPLY_BUTTONS = 3
  URL_REGEX = %r{https?://[^\s<>"']+}
  TRAILING_PUNCTUATION = /[.,;:!?)\]]+\z/

  def api_base_url
    @api_base_url ||= begin
      url = GlobalConfig.get('EVOLUTIONGO_API_URL')['EVOLUTIONGO_API_URL'] || ENV.fetch('EVOLUTIONGO_API_URL', nil)
      url&.chomp('/')
    end
  end

  def global_api_token
    @global_api_token ||= GlobalConfig.get('EVOLUTIONGO_API_TOKEN')['EVOLUTIONGO_API_TOKEN'] || ENV.fetch('EVOLUTIONGO_API_TOKEN', nil)
  end

  def instance_token
    whatsapp_channel.provider_config&.dig('instance_token')
  end

  def instance_id
    whatsapp_channel.provider_config&.dig('instance_id')
  end

  def evolution_go_configured?
    api_base_url.present? && global_api_token.present?
  end

  # --- Instance lifecycle ---

  def create_instance
    return { success: false, error: 'Evolution GO API not configured' } unless evolution_go_configured?

    # Step 1: Create instance with global token.
    # The id is generated here instead of read back from the response: every later call
    # (advanced-settings, delete, health check) is keyed by it, and a blank id silently
    # disables all of them.
    generated_token = SecureRandom.uuid
    generated_instance_id = SecureRandom.uuid
    # EvoGO rejects a duplicate name, so a failed attempt would leave an instance that blocks
    # every retry for the same number. The id suffix keeps the name unique and lets the console
    # be matched against provider_config['instance_id'].
    phone = whatsapp_channel.phone_number&.gsub(/^\+/, '')
    instance_name = "chat_#{phone}_#{generated_instance_id[0, 8]}"

    create_body = {
      name: instance_name,
      token: generated_token,
      instanceId: generated_instance_id,
      advancedSettings: advanced_settings_payload
    }

    response = evolution_request(
      :post,
      "#{api_base_url}/instance/create",
      headers: global_headers,
      body: create_body.to_json,
      timeout: 30
    )

    unless response.success?
      Rails.logger.error "[EVOLUTION_GO] Create instance failed: #{response.body}"
      # EvolutionResponse#message reads `message` or `error`; the raw dig only looked at the
      # first, so the actual reason never reached the user.
      return { success: false, error: response.message }
    end

    parsed = response.parsed_response
    new_instance_token = parsed.dig('data', 'token') || parsed['token'] || generated_token
    new_instance_id = parsed.dig('data', 'id') || parsed['id'] || generated_instance_id

    Rails.logger.info "[EVOLUTION_GO] Instance created. ID: #{new_instance_id}"

    # Save instance credentials to provider_config
    whatsapp_channel.merge_provider_config!(
      'instance_token' => new_instance_token,
      'instance_id' => new_instance_id.to_s
    )

    # Step 2: Start connection (register webhook + subscribe events).
    # Advanced settings ride along with the create call above.
    start_connection

    { success: true, data: parsed }
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] Create instance error: #{e.class} - #{e.message}"
    { success: false, error: e.message }
  end

  def configure_advanced_settings
    return unless instance_id.present? && instance_token.present?

    response = evolution_request(
      :put,
      "#{api_base_url}/instance/#{instance_id}/advanced-settings",
      headers: instance_headers,
      body: advanced_settings_payload.to_json,
      timeout: 15
    )

    if response.success?
      Rails.logger.info "[EVOLUTION_GO] Advanced settings configured"
    else
      Rails.logger.error "[EVOLUTION_GO] Advanced settings failed: #{response.body}"
    end
  end

  # Reads the settings the instance is actually running with. provider_config only records what
  # we last tried to write, and configure_advanced_settings swallows a failed PUT, so the two
  # can drift apart without anyone noticing.
  def fetch_advanced_settings
    return { success: false, error: 'Instance not created' } unless instance_id.present? && instance_token.present?

    response = evolution_request(
      :get,
      "#{api_base_url}/instance/#{instance_id}/advanced-settings",
      headers: instance_headers,
      timeout: 15
    )

    unless response.success?
      Rails.logger.error "[EVOLUTION_GO] Fetch advanced settings failed: #{response.code} - #{response.body}"
      return { success: false, error: response.message }
    end

    data = response.parsed_response['data'] || response.parsed_response

    { success: true, settings: data }
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] Fetch advanced settings error: #{e.class} - #{e.message}"
    { success: false, error: e.message }
  end

  # Instances known to the EvoGO server, used to find ones no channel points at any more.
  # Global token: this asks about the server, not about one instance.
  def list_instances
    return { success: false, error: 'Evolution GO API not configured' } unless evolution_go_configured?

    response = evolution_request(
      :get,
      "#{api_base_url}/instance/all",
      headers: global_headers,
      timeout: 30
    )

    unless response.success?
      return { success: false, error: response.message }
    end

    parsed = response.parsed_response
    { success: true, instances: Array.wrap(parsed['data'] || parsed) }
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] List instances error: #{e.class} - #{e.message}"
    { success: false, error: e.message }
  end

  def instance_info
    return { success: false, error: 'Instance not created' } unless instance_id.present?

    response = evolution_request(
      :get,
      "#{api_base_url}/instance/info/#{instance_id}",
      headers: instance_headers,
      timeout: 15
    )

    return { success: false, error: response.message } unless response.success?

    { success: true, info: response.parsed_response['data'] || response.parsed_response }
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] Instance info error: #{e.class} - #{e.message}"
    { success: false, error: e.message }
  end

  def instance_logs(level: nil, limit: 100)
    return { success: false, error: 'Instance not created' } unless instance_id.present?

    query = { limit: limit }
    query[:level] = level if level.present?

    response = evolution_request(
      :get,
      "#{api_base_url}/instance/logs/#{instance_id}?#{query.to_query}",
      headers: instance_headers,
      timeout: 30
    )

    return { success: false, error: response.message } unless response.success?

    { success: true, logs: response.parsed_response['data'] || response.parsed_response }
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] Instance logs error: #{e.class} - #{e.message}"
    { success: false, error: e.message }
  end

  def start_connection(phone_number: nil)
    return unless instance_token.present?

    webhook_url = build_webhook_url
    phone = (phone_number || whatsapp_channel.phone_number).to_s.gsub(/^\+/, '')

    body = {
      immediate: true,
      phone: phone,
      subscribe: SUBSCRIBED_EVENTS,
      webhookUrl: webhook_url,
      rabbitmqEnable: 'disabled',
      websocketEnable: 'disabled',
      natsEnable: 'disabled'
    }

    response = evolution_request(
      :post,
      "#{api_base_url}/instance/connect",
      headers: instance_headers,
      body: body.to_json,
      timeout: 30
    )

    if response.success?
      Rails.logger.info "[EVOLUTION_GO] Connection started, webhook registered at #{webhook_url}"
    else
      Rails.logger.error "[EVOLUTION_GO] Start connection failed: #{response.body}"
    end
  end

  def delete_instance
    return { success: true } unless evolution_go_configured? && instance_id.present? && instance_token.present?

    response = evolution_request(
      :delete,
      "#{api_base_url}/instance/delete/#{instance_id}",
      headers: global_headers,
      timeout: 15
    )

    # Treat 404 as success: the instance is already gone, which is the outcome we wanted.
    # instance_token and instance_id are kept so the health job can still identify the channel
    # if a later recreation fails midway.
    if response.success? || response.code == 404
      Rails.logger.info "[EVOLUTION_GO] Instance #{instance_id} deleted successfully (or already nonexistent)"

      clear_connection_state

      { success: true }
    else
      Rails.logger.error "[EVOLUTION_GO] Delete instance API failed with code #{response.code}"

      whatsapp_channel.merge_provider_config!('connected' => false, 'connection_status' => 'close')

      { success: false, error: "HTTP #{response.code}: #{response.message}" }
    end
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] Delete instance error: #{e.class} - #{e.message}"
    { success: false, error: e.message }
  end

  # --- Connection methods ---

  def get_qr_code(_options = {})
    unless evolution_go_configured? && instance_token.present?
      return { success: false, error: 'Evolution GO API not configured or instance not created' }
    end

    # Reset connection state before starting new connection attempt
    reset_connection_state

    # Must call start_connection first, then immediately get QR
    start_connection

    response = evolution_request(
      :get,
      "#{api_base_url}/instance/qr",
      headers: instance_headers,
      timeout: 30
    )

    unless response.success?
      Rails.logger.error "[EVOLUTION_GO] QR code failed: #{response.code} - #{response.body}"
      return { success: false, error: "HTTP #{response.code}: #{response.message}" }
    end

    parsed = response.parsed_response
    qr_base64 = parsed.dig('data', 'Qrcode') || parsed.dig('data', 'qrcode')
    code = parsed.dig('data', 'Code') || parsed.dig('data', 'code')

    Rails.logger.info "[EVOLUTION_GO] QR Code received. Has image: #{qr_base64.present?}"

    {
      success: true,
      qr_code: qr_base64,
      pairing_code: nil
    }
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] QR code error: #{e.class} - #{e.message}"
    { success: false, error: e.message }
  end

  def get_pairing_code(phone_number: nil)
    unless evolution_go_configured? && instance_token.present?
      return { success: false, error: 'Evolution GO API not configured or instance not created' }
    end

    phone = (phone_number || whatsapp_channel.phone_number).to_s.gsub(/^\+/, '')

    # Reset connection state before starting new pairing attempt
    reset_connection_state

    # /instance/pair takes no webhookUrl, so without this the number pairs and the inbox
    # receives nothing. Mirrors what get_qr_code already does.
    start_connection(phone_number: phone)

    body = {
      phone: phone,
      subscribe: SUBSCRIBED_EVENTS
    }

    response = evolution_request(
      :post,
      "#{api_base_url}/instance/pair",
      headers: instance_headers,
      body: body.to_json,
      timeout: 30
    )

    unless response.success?
      Rails.logger.error "[EVOLUTION_GO] Pairing code failed: #{response.code} - #{response.body}"
      return { success: false, error: "HTTP #{response.code}: #{response.message}" }
    end

    parsed = response.parsed_response
    pairing_code = parsed.dig('data', 'PairingCode') || parsed.dig('data', 'pairingCode')

    Rails.logger.info "[EVOLUTION_GO] Pairing code received: #{pairing_code.present?}"

    {
      success: true,
      qr_code: nil,
      pairing_code: pairing_code
    }
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] Pairing code error: #{e.class} - #{e.message}"
    { success: false, error: e.message }
  end

  def get_connection_status(force_api_check: false)
    config = whatsapp_channel.reload.provider_config || {}

    # Use cached state unless forced to check the API
    unless force_api_check
      stored_connected = config['connected']
      stored_status = config['connection_status']

      if stored_connected == true && stored_status == 'open'
        return {
          success: true,
          connected: true,
          logged_in: true,
          status: 'open',
          business_name: config['business_name']
        }
      end
    end

    # Poll the API directly
    return { success: false, connected: false, logged_in: false, status: 'close' } unless evolution_go_configured? && instance_token.present?

    begin
      response = evolution_request(
        :get,
        "#{api_base_url}/instance/status",
        headers: instance_headers,
        timeout: 15
      )

      if response.success?
        parsed = response.parsed_response
        data = parsed['data'] || {}

        api_connected = data['Connected'] || data['connected'] || false
        logged_in = data['LoggedIn'] || data['loggedIn'] || false
        name = data['Name'] || data['name'] || ''

        # Both Connected AND LoggedIn must be true for the number to be considered online
        fully_connected = api_connected && logged_in

        if fully_connected
          updates = { 'connected' => true, 'connection_status' => 'open' }
          updates['business_name'] = name if name.present?
          whatsapp_channel.merge_provider_config!(updates)
        elsif config['connection_status'] != 'connecting'
          # Only ever writing the connected side left the cache claiming a live number long
          # after it dropped, and the fast path above answers straight from that cache.
          # 'connecting' is left alone: a pairing attempt is in flight.
          whatsapp_channel.merge_provider_config!('connected' => false, 'connection_status' => 'close')
        end

        {
          success: true,
          connected: fully_connected,
          logged_in: logged_in,
          instance_online: api_connected,
          status: fully_connected ? 'open' : 'close',
          name: name
        }
      else
        { success: false, connected: false, logged_in: false, status: 'close', error_code: response.code }
      end
    rescue StandardError => e
      Rails.logger.error "[EVOLUTION_GO] Status check error: #{e.message}"
      { success: false, connected: false, logged_in: false, status: 'close' }
    end
  end

  def reconnect_instance
    return { success: false, error: 'Instance token not present' } unless instance_token.present?

    response = evolution_request(
      :post,
      "#{api_base_url}/instance/reconnect",
      headers: instance_headers,
      timeout: 30
    )

    msg = response.parsed_response&.dig('message')
    if response.success? && msg == 'success'
      Rails.logger.info "[EVOLUTION_GO] Reconnection request sent successfully"
      { success: true }
    else
      Rails.logger.error "[EVOLUTION_GO] Reconnection request failed: #{response.body}"
      { success: false, error: response.message }
    end
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] Reconnect error: #{e.class} - #{e.message}"
    { success: false, error: e.message }
  end

  # Harder variant of reconnect: tears the session down and dials again. Used when a plain
  # reconnect has not brought the number back.
  def force_reconnect_instance
    return { success: false, error: 'Instance not created' } unless instance_id.present? && instance_token.present?

    phone = whatsapp_channel.phone_number.to_s.gsub(/^\+/, '')

    response = evolution_request(
      :post,
      "#{api_base_url}/instance/forcereconnect/#{instance_id}",
      headers: instance_headers,
      body: { number: phone }.to_json,
      timeout: 30
    )

    if response.success?
      Rails.logger.info "[EVOLUTION_GO] Force reconnect requested for instance #{instance_id}"
      { success: true }
    else
      Rails.logger.error "[EVOLUTION_GO] Force reconnect failed: #{response.code} - #{response.body}"
      { success: false, error: response.message }
    end
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] Force reconnect error: #{e.class} - #{e.message}"
    { success: false, error: e.message }
  end

  def logout
    unless evolution_go_configured? && instance_token.present?
      return { success: false, error: 'Evolution GO API not configured' }
    end

    response = evolution_request(
      :delete,
      "#{api_base_url}/instance/logout",
      headers: instance_headers,
      timeout: 15
    )

    # Update local state regardless of API response
    clear_connection_state

    if response.success?
      Rails.logger.info "[EVOLUTION_GO] Logout successful for instance #{instance_id}"
      { success: true, message: I18n.t('errors.whatsapp.evolution_go.logout_success') }
    else
      Rails.logger.error "[EVOLUTION_GO] Logout API failed: #{response.code} - #{response.body}"
      # Still return success since we cleared local state
      { success: true, message: I18n.t('errors.whatsapp.evolution_go.logout_local_only') }
    end
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] Logout error: #{e.message}"
    { success: false, error: e.message }
  end

  def update_settings
    configure_advanced_settings
  end

  def get_avatar(phone_number_or_jid)
    return nil unless evolution_go_configured? && instance_token.present?

    formatted_number = extract_phone_number(phone_number_or_jid)
    return nil if formatted_number.blank?

    response = evolution_request(
      :post,
      "#{api_base_url}/user/avatar",
      headers: instance_headers,
      body: { number: format_recipient_jid(formatted_number), preview: false }.to_json,
      timeout: 15
    )

    return nil unless response.success?

    response.parsed_response.dig('data', 'url')
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] Get avatar error: #{e.message}"
    nil
  end

  # --- Messaging ---

  def send_message(phone_number_or_jid, message)
    unless evolution_go_configured? && instance_token.present?
      Rails.logger.error "[EVOLUTION_GO] send_message blocked: " \
                         "api_base_url=#{api_base_url.present?} global_api_token=#{global_api_token.present?} " \
                         "instance_token=#{instance_token.present?}"
      return
    end

    if phone_number_or_jid.blank?
      Rails.logger.error "[EVOLUTION_GO] send_message blocked: phone_number_or_jid is blank"
      return
    end

    formatted_number = extract_phone_number(phone_number_or_jid)
    if formatted_number.blank?
      Rails.logger.error "[EVOLUTION_GO] send_message blocked: extract_phone_number returned blank for '#{phone_number_or_jid}'"
      return nil
    end

    Rails.logger.info "[EVOLUTION_GO] Sending to #{formatted_number} (source: #{phone_number_or_jid}) | " \
                      "JID: #{format_recipient_jid(formatted_number)} | attachments: #{message.attachments.count}"

    # Rich types own the whole message, so they are matched before the generic text/media split.
    # /send/location and /send/link claim the source_id themselves; /send/button, /send/list and
    # /send/carousel take no `id`, so their echo is only deduped once the send returns.
    rich_id = send_rich_message(formatted_number, message)
    return rich_id unless rich_id == :not_rich

    reserved_id = reserve_source_id(message)

    sent_id = if message.attachments.any?
                send_message_with_attachments(formatted_number, message, reserved_id)
              else
                send_text_message(formatted_number, message, reserved_id)
              end

    release_source_id(message, reserved_id) if sent_id.blank?
    sent_id
  end

  def delete_message(phone_number_or_jid, external_id)
    return unless evolution_go_configured? && instance_token.present?
    return if phone_number_or_jid.blank? || external_id.blank?

    formatted_number = extract_phone_number(phone_number_or_jid)
    return false if formatted_number.blank?

    chat_id = format_recipient_jid(formatted_number)

    body = {
      chat: chat_id,
      messageId: external_id
    }

    response = evolution_request(
      :post,
      "#{api_base_url}/message/delete",
      headers: instance_headers,
      body: body.to_json,
      timeout: 10
    )

    if response.success?
      Rails.logger.info "[EVOLUTION_GO] Message deleted. ID: #{external_id}"
      true
    else
      Rails.logger.error "[EVOLUTION_GO] Delete message failed: #{response.code} - #{response.body}"
      false
    end
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] Delete message error: #{e.message}"
    false
  end

  def send_template(phone_number, _template_info, message)
    # Evolution GO doesn't use WhatsApp Business templates
    send_message(phone_number, message)
  end

  def sync_templates
    []
  end

  def validate_provider_config?
    whatsapp_channel.phone_number.present?
  end

  def media_url(_media_id)
    nil
  end

  def api_headers
    instance_headers
  end

  private

  def global_headers
    {
      'Content-Type' => 'application/json',
      'apikey' => global_api_token
    }
  end

  def instance_headers
    {
      'Content-Type' => 'application/json',
      'apikey' => instance_token
    }
  end

  # Only alwaysOnline, readMessages and ignoreGroups are user facing; the rest is fixed for this
  # integration. The instance drops group events on its own, so an inbox that has not opted in
  # never even receives them.
  def advanced_settings_payload
    config = whatsapp_channel.provider_config || {}

    {
      alwaysOnline: ['true', true].include?(config['always_online']),
      readMessages: ['true', true].include?(config['read_messages']),
      rejectCall: false,
      ignoreGroups: ['true', true].exclude?(config['groups_enabled']),
      ignoreStatus: true
    }
  end

  def build_webhook_url
    base_url = GlobalConfig.get('FRONTEND_URL')['FRONTEND_URL'] || ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
    phone = whatsapp_channel.phone_number.to_s.gsub(/^\+/, '')
    "#{base_url}/webhooks/evolution_go/#{phone}"
  end

  SESSION_KEYS = %w[business_name jid connected_at].freeze

  def reset_connection_state
    clear_connection_state(status: 'connecting')
  end

  def clear_connection_state(status: 'close')
    whatsapp_channel.merge_provider_config!(
      { 'connected' => false, 'connection_status' => status },
      SESSION_KEYS
    )
  end

  # --- Send methods (private) ---

  # EvoGO echoes our own outgoing messages back through the Message webhook, and that echo can
  # beat the send response back. Claiming the id up front and persisting it before the request
  # means the webhook finds the message already stored and skips it instead of duplicating it.
  # A fresh id is always generated: campaigns pre-fill source_id with a placeholder that must
  # not reach WhatsApp.
  def reserve_source_id(message)
    id = SecureRandom.hex(16).upcase
    message.update_column(:source_id, id)
    id
  end

  # Nothing reached WhatsApp, so the reserved id would point at a message that does not exist.
  def release_source_id(message, reserved_id)
    return if message.source_id != reserved_id

    message.update_column(:source_id, nil)
  end

  def send_text_message(phone_number, message, message_id = nil)
    recipient_jid = format_recipient_jid(phone_number)

    body = {
      number: recipient_jid,
      text: message.outgoing_content,
      delay: message_delay
    }
    body[:id] = message_id if message_id.present?

    quoted = quoted_context(message, recipient_jid)
    body[:quoted] = quoted if quoted.present?

    response = evolution_request(
      :post,
      "#{api_base_url}/send/text",
      headers: instance_headers,
      body: body.to_json,
      timeout: 10
    )

    if response.success?
      msg_id = response.parsed_response.dig('data', 'Info', 'ID')
      Rails.logger.info "[EVOLUTION_GO] Text sent. ID: #{msg_id}"
      msg_id
    else
      Rails.logger.error "[EVOLUTION_GO] Send text failed: #{response.code} - #{response.body}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] Send text error: #{e.message}"
    nil
  end

  def send_message_with_attachments(phone_number, message, reserved_id)
    caption = message.outgoing_content.presence
    # WhatsApp renders a caption only on visual media, and it belongs to a single one of them —
    # repeating it per attachment delivers the text once per file.
    caption_target = message.attachments.find { |a| CAPTIONABLE_TYPES.include?(a.file_type.to_s) }

    sent_ids = message.attachments.each_with_index.map do |attachment, index|
      send_attachment(
        phone_number, attachment, message,
        # Only the first send can carry the reserved id, since that is the one stored as source_id.
        message_id: index.zero? ? reserved_id : nil,
        caption: attachment == caption_target ? caption : nil
      )
    end.compact

    # Nothing in the batch can hold a caption (audio only), so the text needs its own message.
    sent_ids << send_text_message(phone_number, message) if caption.present? && caption_target.nil?

    record_extra_source_ids(message, sent_ids)
    sent_ids.compact.first
  end

  # A Chatwoot message with N attachments becomes N WhatsApp messages, but source_id holds one.
  # The rest are kept so deletion can reach every part instead of orphaning the tail.
  def record_extra_source_ids(message, sent_ids)
    extras = sent_ids.compact.reject { |id| id == message.source_id }
    return if extras.blank?

    message.update_column(:content_attributes, (message.content_attributes || {}).merge('external_ids' => extras))
  end

  # Returns :not_rich when the message is a plain text/media send, so the caller can fall through.
  def send_rich_message(phone_number, message)
    return send_interactive_message(phone_number, message) if message.content_type == 'input_select'
    return send_carousel_message(phone_number, message) if message.content_type == 'cards'
    return send_cta_button_message(phone_number, message) if whatsapp_buttons(message).present?
    return send_link_message(phone_number, message) if link_preview(message).present?

    location = location_attachment(message)
    return send_location_message(phone_number, message, location) if location.present?

    # A message the agent wrote carrying a link goes out through /send/link, which reads the
    # title, the description and the thumbnail off the page itself; /send/text would deliver the
    # bare URL with no card. Restricted to plain text on purpose: input_csat appends the survey
    # link to its own body, and that one is meant to arrive as text, not as a preview card.
    return send_link_message(phone_number, message) if plain_text_with_link?(message)

    :not_rich
  end

  def plain_text_with_link?(message)
    message.content_type == 'text' && message.attachments.empty? && detected_url(message).present?
  end

  # The WhatsApp renderer flattens `[text](url)` to the bare url before this point, so matching
  # the scheme covers markdown links too. The first match wins: an appended agent signature sits
  # at the end, so a link the agent actually wrote takes precedence over one in the signature.
  def detected_url(message)
    # A sentence usually closes right after the link, and that punctuation would travel into the
    # URL and break the lookup on Evolution GO's side.
    message.outgoing_content.to_s[URL_REGEX].to_s.sub(TRAILING_PUNCTUATION, '').presence
  end

  def link_preview(message)
    message.content_attributes&.dig('link_preview').presence
  end

  # Reply buttons ride on input_select, which every other channel understands. Call-to-action and
  # Pix buttons have no equivalent outside Evolution GO and carry fields that
  # ContentAttributeValidator would reject inside `items`, so they travel on their own key of a
  # plain text message, the same way link_preview does.
  def whatsapp_buttons(message)
    message.content_attributes&.dig('whatsapp_buttons').presence
  end

  def location_attachment(message)
    message.attachments.find { |attachment| attachment.file_type.to_s == 'location' }
  end

  # Chatwoot stores a location as an attachment with coordinates rather than a file, which is the
  # same shape Telegram and the other channels use.
  def send_location_message(phone_number, message, attachment)
    recipient_jid = format_recipient_jid(phone_number)
    reserved_id = reserve_source_id(message)

    body = {
      number: recipient_jid,
      id: reserved_id,
      latitude: attachment.coordinates_lat,
      longitude: attachment.coordinates_long,
      delay: message_delay
    }
    # Evolution GO answers /send/location with "name is required" as well as "address is required",
    # and the form only asks for the address: a Maps link for a plain address carries no place name.
    # The address then stands in for both, which is what WhatsApp shows anyway when a pin has no name.
    body[:name] = attachment.fallback_title.presence || message.content
    body[:address] = message.content

    quoted = quoted_context(message, recipient_jid)
    body[:quoted] = quoted if quoted.present?

    sent_id = post_send('send/location', body, 'Location')
    release_source_id(message, reserved_id) if sent_id.blank?
    sent_id
  end

  # Two ways in: a link detected in the message text, or content_attributes['link_preview'] set
  # through the API by a caller that wants to override the card the page would produce.
  def send_link_message(phone_number, message)
    recipient_jid = format_recipient_jid(phone_number)
    preview = link_preview(message) || {}
    reserved_id = reserve_source_id(message)

    body = {
      number: recipient_jid,
      id: reserved_id,
      url: preview['url'].presence || detected_url(message),
      text: message.outgoing_content.presence || preview['url'],
      delay: message_delay
    }
    body[:title] = preview['title'] if preview['title'].present?
    body[:description] = preview['description'] if preview['description'].present?
    body[:imgUrl] = preview['image_url'] if preview['image_url'].present?

    quoted = quoted_context(message, recipient_jid)
    body[:quoted] = quoted if quoted.present?

    sent_id = post_send('send/link', body, 'Link')
    release_source_id(message, reserved_id) if sent_id.blank?
    sent_id
  end

  # Chatwoot's `cards` content type maps onto the carousel: each item becomes a card whose header
  # holds the title and image, the body the description, and the actions the buttons.
  def send_carousel_message(phone_number, message)
    recipient_jid = format_recipient_jid(phone_number)
    attributes = message.content_attributes || {}

    body = {
      number: recipient_jid,
      body: message.outgoing_content,
      cards: Array(attributes['items']).map { |item| carousel_card(item) },
      delay: message_delay
    }
    body[:footer] = attributes['footer'] if attributes['footer'].present?

    quoted = quoted_context(message, recipient_jid)
    body[:quoted] = quoted if quoted.present?

    post_send('send/carousel', body, 'Carousel')
  end

  # ContentAttributeValidator only accepts title/description/media_url/actions on a card, so the
  # header carries no subtitle and the description becomes the card body.
  def carousel_card(item)
    header = { title: item['title'] }
    header[:imageUrl] = item['media_url'] if item['media_url'].present?

    {
      header: header,
      # The card body is required by the endpoint and the description is optional in Chatwoot.
      body: { text: item['description'].presence || item['title'].to_s },
      buttons: Array(item['actions']).map { |action| carousel_button(action) }
    }
  end

  # Chatwoot action types are lowercase; the carousel endpoint expects REPLY, URL, CALL or COPY,
  # and puts the destination in `id` for all of them.
  CAROUSEL_BUTTON_TYPES = { 'link' => 'URL', 'call' => 'CALL', 'copy' => 'COPY' }.freeze

  def carousel_button(action)
    type = CAROUSEL_BUTTON_TYPES.fetch(action['type'].to_s, 'REPLY')

    button = {
      type: type,
      displayText: action['text'],
      id: action['uri'].presence || action['payload'].presence || action['text']
    }
    # COPY is the one kind that keeps the code in its own field instead of in `id`.
    button[:copyCode] = action['payload'] if type == 'COPY'

    button
  end

  # Chatwoot models an interactive message as content_type input_select, with the options in
  # content_attributes.items ([{title:, value:}]). Same split the Cloud and 360dialog providers
  # use: buttons while they fit, a list past that.
  # Neither endpoint accepts an `id`, so these two cannot pre-claim the source_id the way text
  # and media do — the webhook echo is deduped by the exists?(source_id:) check alone.
  def send_interactive_message(phone_number, message)
    items = Array(message.content_attributes&.dig('items'))

    if items.size <= MAX_REPLY_BUTTONS
      send_button_message(phone_number, message, items)
    else
      send_list_message(phone_number, message, items)
    end
  end

  def send_button_message(phone_number, message, items)
    attributes = message.content_attributes || {}

    body = interactive_body(phone_number, message, attributes).merge(
      footer: attributes['footer'].presence,
      buttons: items.map { |item| interactive_item_button(item) }
    )

    post_send('send/button', body, 'Buttons')
  end

  # An item with a `uri` (set by the automation rule builder for a link button) becomes a real
  # URL button on Evolution GO's own /send/button schema; everything else stays a quick reply.
  def interactive_item_button(item)
    return { type: 'url', displayText: item['title'], url: item['uri'] } if item['uri'].present?

    { type: 'reply', displayText: item['title'], id: item['value'] }
  end

  # Call-to-action and Pix buttons. The endpoint is the same one the reply buttons use, but the
  # server rejects mixing the two kinds, so they never share a message.
  def send_cta_button_message(phone_number, message)
    attributes = whatsapp_buttons(message)

    body = interactive_body(phone_number, message, attributes).merge(
      footer: attributes['footer'].presence,
      buttons: Array(attributes['buttons']).map { |button| cta_button(button) }
    )
    body[:imageUrl] = attributes['image_url'] if attributes['image_url'].present?

    post_send('send/button', body, 'CTA buttons')
  end

  # Every kind carries displayText except pix, which renders a payment sheet built from the key.
  def cta_button(button)
    payload = { type: button['type'] }

    case button['type'].to_s
    when 'url'
      payload.merge(displayText: button['text'], url: button['url'])
    when 'call'
      payload.merge(displayText: button['text'], phoneNumber: button['phone_number'])
    when 'copy'
      payload.merge(displayText: button['text'], copyCode: button['copy_code'], id: button['copy_code'])
    when 'pix'
      payload.merge(key: button['key'], keyType: button['key_type'], name: button['name'], currency: button['currency'])
    else
      payload.merge(displayText: button['text'], id: button['text'])
    end
  end

  def send_list_message(phone_number, message, items)
    attributes = message.content_attributes || {}
    rows = items.map { |item| { rowId: item['value'], title: item['title'] } }

    body = interactive_body(phone_number, message, attributes).merge(
      footerText: attributes['footer'].presence,
      buttonText: list_button_label,
      sections: [{ rows: rows }]
    )

    post_send('send/list', body, 'List')
  end

  # The label the contact taps to open the list. The send runs in a background job, where
  # I18n.locale is still the default, so the account's language has to be named explicitly or
  # every list goes out in English.
  def list_button_label
    I18n.t('conversations.messages.whatsapp.list_button_label', locale: whatsapp_channel.account.locale)
  end

  # description carries the message body and title the header above it. EvoGO rejects the send
  # without a title ("title is required"), but the footer is optional and each endpoint names it
  # differently (`footer` on /send/button, `footerText` on /send/list), so the callers add it.
  def interactive_body(phone_number, message, attributes = nil)
    recipient_jid = format_recipient_jid(phone_number)
    attributes ||= message.content_attributes || {}

    body = {
      number: recipient_jid,
      title: attributes['title'],
      description: message.outgoing_content,
      delay: message_delay
    }

    quoted = quoted_context(message, recipient_jid)
    body[:quoted] = quoted if quoted.present?

    body
  end

  def post_send(endpoint, body, label)
    response = evolution_request(
      :post,
      "#{api_base_url}/#{endpoint}",
      headers: instance_headers,
      body: body.to_json,
      timeout: 30
    )

    if response.success?
      msg_id = response.parsed_response.dig('data', 'Info', 'ID') || response.parsed_response.dig('data', 'key', 'id')
      Rails.logger.info "[EVOLUTION_GO] #{label} sent. ID: #{msg_id}"
      msg_id
    else
      Rails.logger.error "[EVOLUTION_GO] #{label} failed: #{response.code} - #{response.body}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] #{label} error: #{e.class} - #{e.message}"
    nil
  end

  # Every media type goes through /send/media: EvoGO exposes no /send/audio endpoint.
  def send_attachment(phone_number, attachment, message, message_id: nil, caption: nil)
    file_url = attachment_url(attachment)
    media_type = case attachment.file_type.to_s
                 when 'image' then 'image'
                 when 'video' then 'video'
                 when 'audio' then 'audio'
                 else 'document'
                 end

    recipient_jid = format_recipient_jid(phone_number)

    body = {
      number: recipient_jid,
      type: media_type,
      url: file_url,
      filename: attachment.file.filename.to_s,
      delay: message_delay
    }
    body[:id] = message_id if message_id.present?
    body[:caption] = caption if caption.present?

    quoted = quoted_context(message, recipient_jid)
    body[:quoted] = quoted if quoted.present?

    response = evolution_request(
      :post,
      "#{api_base_url}/send/media",
      headers: instance_headers,
      body: body.to_json,
      timeout: 30
    )

    if response.success?
      msg_id = response.parsed_response.dig('data', 'Info', 'ID') || response.parsed_response.dig('data', 'key', 'id')
      Rails.logger.info "[EVOLUTION_GO] Media sent (#{media_type}). ID: #{msg_id}"
      msg_id
    else
      Rails.logger.error "[EVOLUTION_GO] Send media failed (#{media_type}): #{response.code} - #{response.body}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] Send media error: #{e.message}"
    nil
  end

  def attachment_url(attachment)
    if attachment.file.service_name.to_s.match?(/s3|minio|amazon/)
      attachment.file.url(expires_in: 10.minutes)
    else
      attachment.download_url
    end
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] Attachment URL error: #{e.message}"
    attachment.download_url
  end

  # Build quoted context for reply messages.
  # EvoGO expects { messageId, participant } format.
  def quoted_context(message, recipient_jid)
    reply_to_id = message.content_attributes&.dig('in_reply_to_external_id') ||
                  message.content_attributes&.dig(:in_reply_to_external_id)
    return nil if reply_to_id.blank?

    original_message = message.conversation&.messages&.find_by(source_id: reply_to_id)
    return nil unless original_message

    # Ingested messages record the JID WhatsApp actually used for their author; only messages
    # composed here have to be resolved by hand.
    participant = original_message.content_attributes&.dig('sender_jid').presence ||
                  if original_message.incoming?
                    contact_jid_for(message.conversation)
                  else
                    owner_jid(recipient_jid)
                  end

    {
      messageId: reply_to_id,
      participant: participant
    }.compact
  end

  def contact_jid_for(conversation)
    phone = conversation.contact&.phone_number.to_s.gsub(/^\+/, '')
    "#{phone}@s.whatsapp.net" if phone.present?
  end

  # In a LID chat WhatsApp knows us by our own LID, captured at PairSuccess, not by the phone
  # JID — quoting one of our messages there fails when addressed the other way.
  def owner_jid(recipient_jid)
    if recipient_jid.to_s.end_with?('@lid')
      lid = whatsapp_channel.provider_config&.dig('lid').to_s.split(':').first
      return "#{lid}@lid" if lid.present?
    end

    phone = whatsapp_channel.phone_number.to_s.gsub(/^\+/, '')
    "#{phone}@s.whatsapp.net" if phone.present?
  end

  # A value that already names its own domain is a full jid and must survive untouched. EvoGO
  # addresses a group that way, and the length heuristic in format_recipient_jid cannot tell an
  # 18 digit group id from a lid, so stripping the domain here would send the message to a
  # @lid that does not exist. The device suffix is dropped for the same reason the incoming
  # service drops it.
  KNOWN_JID_DOMAINS = ['@g.us', '@lid', '@s.whatsapp.net'].freeze

  def known_jid(value)
    jid = value.to_s.gsub(/:[^@]+/, '')
    jid if KNOWN_JID_DOMAINS.any? { |domain| jid.end_with?(domain) }
  end

  def extract_phone_number(value)
    return nil if value.blank?

    jid = known_jid(value)
    return jid if jid.present?

    # Get the part before @, then take the part before any : (device ID)
    phone = value.to_s.split('@').first.split(':').first.gsub(/^\+/, '')
    # Allow digits (phone) or long alphanumeric strings (LID)
    phone.match?(/^[a-zA-Z0-9]+$/) ? phone : nil
  end

  def format_recipient_jid(source_id)
    known = known_jid(source_id)
    return known if known.present?

    # If it's a LID (starts with 1 or 2 and is long, or we detected it before)
    # Standard phone numbers are usually shorter than LIDs
    if source_id.length > 15 || source_id.start_with?('1', '2')
      # Most LIDs in logs start with 1 or 2 and are ~14-15 digits, 
      # but some phone numbers can be 13.
      # To be safe, if it doesn't look like a standard phone number, treat as LID
      # if it's already in our database as LID.
      return "#{source_id}@lid" if source_id.length >= 14
    end

    "#{source_id}@s.whatsapp.net"
  end

  # delay_time is stored in seconds. Older builds stored milliseconds and told the two apart by
  # a > 100 threshold, which turned any delay above 100s into milliseconds; the values were
  # normalized by NormalizeEvolutionGoDelayTime.
  def message_delay
    config = whatsapp_channel.provider_config || {}
    return 0 if [false, 'false'].include?(config['delay_enabled'])

    (config['delay_time'] || 2).to_i * 1000
  end

  class EvolutionResponse
    attr_reader :code, :body, :parsed_response

    def initialize(success, code, body, parsed_response)
      @success = success
      @code = code
      @body = body
      @parsed_response = parsed_response
    end

    def success?
      @success
    end

    def message
      parsed_response&.dig('message') || parsed_response&.dig('error') || body.presence || "HTTP #{code}"
    end
  end

  def evolution_request(method, path_or_url, headers: {}, body: nil, timeout: 30)
    path = path_or_url
    if path_or_url.start_with?(api_base_url)
      path = path_or_url.sub(api_base_url, '').sub(/^\//, '')
    end

    conn = Whatsapp::Providers::EvolutionClient.connection(api_base_url)
    response = conn.send(method, path) do |req|
      req.headers = headers
      req.body = body if body.present?
      req.options.timeout = timeout
    end

    parsed_response = begin
      JSON.parse(response.body)
    rescue
      {}
    end

    EvolutionResponse.new(response.success?, response.status, response.body, parsed_response)
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION CLIENT ERROR] #{e.class} - #{e.message}"
    EvolutionResponse.new(false, 500, '', {})
  end
end
