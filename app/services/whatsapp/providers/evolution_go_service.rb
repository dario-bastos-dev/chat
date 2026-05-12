class Whatsapp::Providers::EvolutionGoService < Whatsapp::Providers::BaseService
  # EvolutionGO uses a different authentication model:
  # - Global token (EVOLUTIONGO_API_TOKEN) for creating instances
  # - Instance token (stored in provider_config) for all other operations

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

    # Step 1: Create instance with global token
    generated_token = SecureRandom.uuid
    instance_name = "chat_#{whatsapp_channel.phone_number&.gsub(/^\+/, '')}"

    create_body = {
      name: instance_name,
      token: generated_token
    }

    response = HTTParty.post(
      "#{api_base_url}/instance/create",
      headers: global_headers,
      body: create_body.to_json,
      timeout: 30
    )

    unless response.success?
      Rails.logger.error "[EVOLUTION_GO] Create instance failed: #{response.body}"
      return { success: false, error: response.parsed_response&.dig('message') || 'Failed to create instance' }
    end

    parsed = response.parsed_response
    new_instance_token = parsed.dig('data', 'token') || parsed['token'] || generated_token
    new_instance_id = parsed.dig('data', 'id') || parsed['id']

    Rails.logger.info "[EVOLUTION_GO] Instance created. ID: #{new_instance_id}"

    # Save instance credentials to provider_config
    config = whatsapp_channel.provider_config || {}
    config['instance_token'] = new_instance_token
    config['instance_id'] = new_instance_id.to_s
    whatsapp_channel.update_column(:provider_config, config)

    # Step 2: Configure advanced settings
    configure_advanced_settings

    # Step 3: Start connection (register webhook + subscribe events)
    start_connection

    { success: true, data: parsed }
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] Create instance error: #{e.class} - #{e.message}"
    { success: false, error: e.message }
  end

  def configure_advanced_settings
    return unless instance_id.present? && instance_token.present?

    config = whatsapp_channel.provider_config || {}

    settings = {
      alwaysOnline: ['true', true].include?(config['always_online']),
      readMessages: ['true', true].include?(config['read_messages']),
      rejectCall: true,
      ignoreGroups: true,
      ignoreStatus: true
    }

    response = HTTParty.put(
      "#{api_base_url}/instance/#{instance_id}/advanced-settings",
      headers: instance_headers,
      body: settings.to_json,
      timeout: 15
    )

    if response.success?
      Rails.logger.info "[EVOLUTION_GO] Advanced settings configured"
    else
      Rails.logger.error "[EVOLUTION_GO] Advanced settings failed: #{response.body}"
    end
  end

  def start_connection
    return unless instance_token.present?

    webhook_url = build_webhook_url
    phone = whatsapp_channel.phone_number.to_s.gsub(/^\+/, '')

    body = {
      immediate: true,
      phone: phone,
      subscribe: %w[MESSAGE CONNECTION READ_RECEIPT],
      webhookUrl: webhook_url,
      rabbitmqEnable: 'disabled',
      websocketEnable: 'disabled',
      natsEnable: 'disabled'
    }

    response = HTTParty.post(
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

    response = HTTParty.delete(
      "#{api_base_url}/instance/delete/#{instance_id}",
      headers: global_headers,
      timeout: 15
    )

    if response.success?
      Rails.logger.info "[EVOLUTION_GO] Instance #{instance_id} deleted successfully"
      { success: true }
    else
      Rails.logger.error "[EVOLUTION_GO] Delete instance failed: #{response.code} - #{response.body}"
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

    response = HTTParty.get(
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

    body = {
      phone: phone,
      subscribe: %w[MESSAGE CONNECTION READ_RECEIPT]
    }

    response = HTTParty.post(
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

  def get_connection_status
    # Primary source: provider_config updated by PairSuccess webhook
    config = whatsapp_channel.reload.provider_config || {}
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

    # Fallback: poll the API if webhook hasn't fired yet
    return { success: false, connected: false, logged_in: false, status: 'close' } unless evolution_go_configured? && instance_token.present?

    begin
      response = HTTParty.get(
        "#{api_base_url}/instance/status",
        headers: instance_headers,
        timeout: 15
      )

      if response.success?
        parsed = response.parsed_response
        data = parsed['data'] || {}

        # Connected = instance online on EvoGO server
        # LoggedIn = WhatsApp number actually authenticated (THIS is the real status)
        api_connected = data['Connected'] || data['connected'] || false
        logged_in = data['LoggedIn'] || data['loggedIn'] || false
        name = data['Name'] || data['name'] || ''

        if logged_in
          # Sync API state to provider_config
          config['connected'] = true
          config['connection_status'] = 'open'
          config['business_name'] = name if name.present?
          whatsapp_channel.update_column(:provider_config, config)
        end

        {
          success: true,
          connected: logged_in,
          logged_in: logged_in,
          instance_online: api_connected,
          status: logged_in ? 'open' : 'close',
          name: name
        }
      else
        { success: false, connected: false, logged_in: false, status: 'close' }
      end
    rescue StandardError => e
      Rails.logger.error "[EVOLUTION_GO] Status check error: #{e.message}"
      { success: false, connected: false, logged_in: false, status: 'close' }
    end
  end

  def logout
    unless evolution_go_configured? && instance_token.present?
      return { success: false, error: 'Evolution GO API not configured' }
    end

    response = HTTParty.delete(
      "#{api_base_url}/instance/logout",
      headers: instance_headers,
      timeout: 15
    )

    # Update local state regardless of API response
    config = whatsapp_channel.provider_config || {}
    config['connected'] = false
    config['connection_status'] = 'close'
    config.delete('business_name')
    config.delete('jid')
    config.delete('connected_at')
    whatsapp_channel.update_column(:provider_config, config)

    if response.success?
      Rails.logger.info "[EVOLUTION_GO] Logout successful for instance #{instance_id}"
      { success: true, message: 'Desconectado com sucesso' }
    else
      Rails.logger.error "[EVOLUTION_GO] Logout API failed: #{response.code} - #{response.body}"
      # Still return success since we cleared local state
      { success: true, message: 'Desconectado localmente' }
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

    response = HTTParty.post(
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
    return unless evolution_go_configured? && instance_token.present?
    return if phone_number_or_jid.blank?

    formatted_number = extract_phone_number(phone_number_or_jid)
    return nil if formatted_number.blank?

    if message.attachments.any?
      send_message_with_attachments(formatted_number, message)
    else
      send_text_message(formatted_number, message)
    end
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

    response = HTTParty.post(
      "#{api_base_url}/message/delete",
      headers: instance_headers,
      body: body.to_json,
      timeout: 10
    )

    if response.success?
      Rails.logger.info "[EVOLUTION_GO] ✅ Message deleted. ID: #{external_id}"
      true
    else
      Rails.logger.error "[EVOLUTION_GO] ❌ Delete message failed: #{response.code} - #{response.body}"
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

  def build_webhook_url
    base_url = GlobalConfig.get('FRONTEND_URL')['FRONTEND_URL'] || ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
    phone = whatsapp_channel.phone_number.to_s.gsub(/^\+/, '')
    "#{base_url}/webhooks/evolution_go/#{phone}"
  end

  def reset_connection_state
    config = whatsapp_channel.provider_config || {}
    config['connected'] = false
    config['connection_status'] = 'connecting'
    config.delete('business_name')
    config.delete('jid')
    config.delete('connected_at')
    whatsapp_channel.update_column(:provider_config, config)
  end

  # --- Send methods (private) ---

  def send_text_message(phone_number, message)
    body = {
      number: format_recipient_jid(phone_number),
      text: message.outgoing_content,
      delay: message_delay
    }

    quoted = quoted_context(message)
    body[:quoted] = quoted if quoted.present?

    response = HTTParty.post(
      "#{api_base_url}/send/text",
      headers: instance_headers,
      body: body.to_json,
      timeout: 10
    )

    if response.success?
      msg_id = response.parsed_response.dig('data', 'Info', 'ID')
      Rails.logger.info "[EVOLUTION_GO] ✅ Text sent. ID: #{msg_id}"
      msg_id
    else
      Rails.logger.error "[EVOLUTION_GO] ❌ Send text failed: #{response.code} - #{response.body}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] Send text error: #{e.message}"
    nil
  end

  def send_message_with_attachments(phone_number, message)
    message_id = nil

    message.attachments.each do |attachment|
      response = send_attachment(phone_number, attachment, message)
      message_id ||= response if response.present?
    end

    # If text + only audio attachments (no caption support), send text separately
    if message.content.present? && message.attachments.none? { |a| %w[image video file].include?(a.file_type.to_s) }
      text_response = send_text_message(phone_number, message)
      message_id ||= text_response
    end

    message_id
  end

  def send_attachment(phone_number, attachment, message)
    file_url = attachment_url(attachment)
    file_type = attachment.file_type.to_s

    media_type = case file_type
                 when 'image' then 'image'
                 when 'video' then 'video'
                 when 'audio' then 'audio'
                 else 'document'
                 end

    # Caption only for image, video, document (not audio)
    caption = %w[image video file document].include?(file_type) ? (message.outgoing_content.presence || '') : nil

    body = {
      number: format_recipient_jid(phone_number),
      type: media_type,
      url: file_url,
      filename: attachment.file.filename.to_s,
      delay: message_delay
    }
    body[:caption] = caption if caption.present?

    quoted = quoted_context(message)
    body[:quoted] = quoted if quoted.present?

    Rails.logger.info "[EVOLUTION_GO] Sending #{media_type} to #{phone_number}"

    response = HTTParty.post(
      "#{api_base_url}/send/media",
      headers: instance_headers,
      body: body.to_json,
      timeout: 30
    )

    if response.success?
      msg_id = response.parsed_response.dig('data', 'Info', 'ID')
      Rails.logger.info "[EVOLUTION_GO] ✅ Media sent. ID: #{msg_id}"
      msg_id
    else
      Rails.logger.error "[EVOLUTION_GO] ❌ Send media failed: #{response.code} - #{response.body}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] Send media error: #{e.message}"
    nil
  end

  def attachment_url(attachment)
    if attachment.file.service_name.to_s.match?(/s3|minio/)
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
  def quoted_context(message)
    reply_to_id = message.content_attributes&.dig('in_reply_to_external_id') ||
                  message.content_attributes&.dig(:in_reply_to_external_id)
    return nil if reply_to_id.blank?

    original_message = message.conversation&.messages&.find_by(source_id: reply_to_id)
    return nil unless original_message

    # Determine participant: the sender of the original message
    participant = if original_message.incoming?
                    contact_jid_for(message.conversation)
                  else
                    owner_jid
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

  def owner_jid
    phone = whatsapp_channel.phone_number.to_s.gsub(/^\+/, '')
    "#{phone}@s.whatsapp.net" if phone.present?
  end

  def extract_phone_number(value)
    return nil if value.blank?

    # Get the part before @, then take the part before any : (device ID)
    phone = value.to_s.split('@').first.split(':').first.gsub(/^\+/, '')
    # Allow digits (phone) or long alphanumeric strings (LID)
    phone.match?(/^[a-zA-Z0-9]+$/) ? phone : nil
  end

  def format_recipient_jid(source_id)
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

  def message_delay
    config = whatsapp_channel.provider_config || {}
    return 0 if [false, 'false'].include?(config['delay_enabled'])

    val = (config['delay_time'] || 2).to_i
    # If the value is > 100, it's likely already in milliseconds (legacy)
    # Otherwise, convert from seconds to ms
    val > 100 ? val : val * 1000
  end
end
