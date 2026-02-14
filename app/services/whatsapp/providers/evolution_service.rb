class Whatsapp::Providers::EvolutionService < Whatsapp::Providers::BaseService
  # Memoize config values to avoid repeated GlobalConfig queries
  def api_base_url
    @api_base_url ||= begin
      url = GlobalConfig.get('EVOLUTION_API_URL')['EVOLUTION_API_URL'] || ENV.fetch('EVOLUTION_API_URL', nil)
      url&.chomp('/')
    end
  end

  def api_token
    @api_token ||= GlobalConfig.get('EVOLUTION_API_TOKEN')['EVOLUTION_API_TOKEN'] || ENV.fetch('EVOLUTION_API_TOKEN', nil)
  end

  def instance_name
    @instance_name ||= whatsapp_channel.phone_number&.gsub(/^\+/, '')
  end

  def evolution_configured?
    api_base_url.present? && api_token.present?
  end

  def send_message(phone_number_or_jid, message)
    return unless evolution_configured?
    return if phone_number_or_jid.blank?

    formatted_number = extract_phone_number(phone_number_or_jid)
    return nil if formatted_number.blank?

    # Check if message has attachments
    if message.attachments.any?
      send_message_with_attachments(formatted_number, message)
    else
      send_text_message(formatted_number, message)
    end
  end

  def send_text_message(phone_number, message)
    response = HTTParty.post(
      "#{api_base_url}/message/sendText/#{instance_name}",
      headers: api_headers,
      body: {
        number: phone_number,
        text: message.content
      }.to_json,
      timeout: 10  # Add timeout for better performance
    )

    if response.success?
      response.parsed_response.dig('key', 'id')
    else
      Rails.logger.error "[EVOLUTION] Send failed: #{response.code}"
      nil
    end
  end

  def send_message_with_attachments(phone_number, message)
    message_id = nil

    message.attachments.each do |attachment|
      response = send_attachment(phone_number, attachment, message)
      message_id ||= response if response.present?
    end

    # If there's also text content (caption), send it separately if not sent with media
    if message.content.present? && message.attachments.none? { |a| a.file_type == 'image' || a.file_type == 'video' }
      text_response = send_text_message(phone_number, message)
      message_id ||= text_response
    end

    message_id
  end

  def send_attachment(phone_number, attachment, message)
    # Get direct URL if possible to avoid 302 Redirect issues with Evolution
    # And strip signatures as requested
    raw_url = if attachment.file.service_name.to_s.include?('s3') || attachment.file.service_name.to_s.include?('minio')
                 attachment.file.url(expires_in: 10.minutes)
               else
                 attachment.download_url
               end

    # Remove signature/query params to send clean direct URL
    begin
      uri = URI.parse(raw_url)
      uri.query = nil
      file_url = uri.to_s
    rescue URI::InvalidURIError
      file_url = raw_url
    end
               
    file_type = attachment.file_type
    caption = message.content

    Rails.logger.info "[EVOLUTION] Sending #{file_type} attachment to #{phone_number}"
    Rails.logger.debug "[EVOLUTION] Media URL: #{file_url}"

    endpoint = case file_type.to_s
               when 'image' then 'sendMedia'
               when 'video' then 'sendMedia'
               when 'audio' then 'sendWhatsAppAudio'
               else 'sendMedia'
               end

    # Evolution API expects 'document' for files, not 'file'
    evolution_media_type = case file_type.to_s
                           when 'image' then 'image'
                           when 'video' then 'video'
                           when 'audio' then 'audio'
                           else 'document'
                           end

    # Specific body construction based on endpoint
    if endpoint == 'sendWhatsAppAudio'
      body = {
        number: phone_number,
        audio: file_url
      }
    else
      body = {
        number: phone_number,
        mediatype: evolution_media_type,
        media: file_url,
        caption: caption.presence || '',
        fileName: attachment.file.filename.to_s
      }
      
      # For audio files sent via sendMedia, add mimetype
      if evolution_media_type == 'audio'
        body[:mimetype] = 'audio/mp4' # Default fallback, or could extract from attachment
        # Helper to get precise mime if available
        real_mime = attachment.file.content_type rescue nil
        body[:mimetype] = real_mime if real_mime.present?
      end
    end

    Rails.logger.info "[EVOLUTION DEBUG] Body: #{body.to_json}"

    response = HTTParty.post(
      "#{api_base_url}/message/#{endpoint}/#{instance_name}",
      headers: api_headers,
      body: body.to_json,
      timeout: 30 # Prevent blocking worker on slow media uploads
    )
    
    Rails.logger.info "[EVOLUTION DEBUG] Response: #{response.code} / #{response.body}"

    if response.success?
      message_id = response.parsed_response.dig('key', 'id')
      Rails.logger.info "[EVOLUTION] ✅ Attachment sent. ID: #{message_id}"
      message_id
    else
      Rails.logger.error "[EVOLUTION] ❌ Send attachment failed: #{response.code} - #{response.body}"
      nil
    end
  end

  # Extract clean phone number from various formats
  def extract_phone_number(value)
    return nil if value.blank?
    
    # Remove @ suffix if present (JID format)
    phone = value.to_s.split('@').first
    # Remove + if present
    phone = phone.gsub(/^\+/, '')
    # Return only if it looks like a phone number (digits only)
    phone.match?(/^\d+$/) ? phone : nil
  end

  def send_template(phone_number, template_info, message)
    # Evolution API doesn't use WhatsApp Business templates
    # Send as regular message instead
    send_message(phone_number, message)
  end

  def sync_templates
    # Evolution API doesn't sync WhatsApp Business templates
    []
  end

  def validate_provider_config?
    whatsapp_channel.phone_number.present?
  end

  def media_url(media_id)
    nil
  end

  # Fetch Base64 media content from Evolution API using message keyId
  # Used to recover media from messages sent directly from the phone (fromMe)
  # See: docs/example/incoming_messages.md
  def get_base64_from_media_message(key_id)
    return nil unless evolution_configured? && key_id.present?

    url = "#{api_base_url}/chat/getBase64FromMediaMessage/#{instance_name}"

    body = {
      message: {
        key: {
          id: key_id
        }
      },
      convertToMp4: false
    }

    Rails.logger.info "[EVOLUTION] Fetching base64 media for keyId: #{key_id}"

    response = HTTParty.post(
      url,
      headers: api_headers,
      body: body.to_json,
      timeout: 30
    )

    if response.success?
      parsed = response.parsed_response
      Rails.logger.info "[EVOLUTION] Base64 media fetched successfully for keyId: #{key_id}"
      parsed
    else
      Rails.logger.error "[EVOLUTION] Failed to fetch base64 media: #{response.code} - #{response.body.to_s.truncate(200)}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION] Error fetching base64 media: #{e.message}"
    nil
  end

  def api_headers
    {
      'Content-Type' => 'application/json',
      'apikey' => api_token
    }
  end

  # Create instance in Evolution API with Chatwoot webhook
  def create_instance
    return { success: false, error: 'Evolution API not configured' } unless evolution_configured?

    webhook_url = build_webhook_url
    config = whatsapp_channel.provider_config || {}

    body = {
      instanceName: instance_name,
      number: whatsapp_channel.phone_number.gsub(/^\+/, ''),
      qrcode: false,
      integration: 'WHATSAPP-BAILEYS',
      rejectCall: ['true', true].include?(config['reject_calls']),
      msgCall: config['msg_call'] || '',
      groupsIgnore: ['true', true].include?(config['ignore_groups']),
      alwaysOnline: ['true', true].include?(config['always_online']),
      readMessages: ['true', true].include?(config['read_messages']),
      readStatus: ['true', true].include?(config['read_status']),
      syncFullHistory: ['true', true].include?(config['sync_full_history']),
      webhook: {
        url: webhook_url,
        webhook_by_events: false,
        webhook_base64: true,
        events: %w[QRCODE_UPDATED MESSAGES_UPSERT MESSAGES_UPDATE CONNECTION_UPDATE SEND_MESSAGE]
      }
    }

    response = HTTParty.post(
      "#{api_base_url}/instance/create",
      headers: api_headers,
      body: body.to_json
    )

    if response.success?
      # Apply behavior settings immediately
      update_settings
      { success: true, data: response.parsed_response }
    else
      Rails.logger.error "[EVOLUTION] Create instance failed: #{response.body}"
      { success: false, error: response.parsed_response['message'] || 'Failed to create instance' }
    end
  end

  def update_settings
    Rails.logger.info "[EVOLUTION] update_settings called for #{instance_name}"
    
    config = whatsapp_channel.provider_config || {}
    Rails.logger.info "[EVOLUTION] Current provider_config: #{config.inspect}"
    
    settings = {
      rejectCall: ['true', true].include?(config['reject_calls']),
      msgCall: config['msg_call'] || '',
      groupsIgnore: ['true', true].include?(config['ignore_groups']),
      alwaysOnline: ['true', true].include?(config['always_online']),
      readMessages: ['true', true].include?(config['read_messages']),
      syncFullHistory: ['true', true].include?(config['sync_full_history']),
      readStatus: ['true', true].include?(config['read_status'])
    }

    Rails.logger.info "[EVOLUTION] Settings to send: #{settings.inspect}"

    url = "#{api_base_url}/settings/set/#{instance_name}"
    Rails.logger.info "[EVOLUTION] Calling Evolution API: #{url}"
    
    response = HTTParty.post(
      url,
      headers: api_headers,
      body: settings.to_json
    )

    if response.success?
      Rails.logger.info "[EVOLUTION] Settings updated successfully: #{response.body}"
      # Also sync webhook configuration to ensure all events are registered
      update_webhook
    else
      Rails.logger.error "[EVOLUTION] Update settings failed: #{response.body}"
      raise "Evolution API Update Failed: #{response.code} - #{response.body}"
    end
  end

  # Ensure webhook is properly configured with all required events
  # This fixes issues where the instance was created before all events were registered
  def update_webhook
    webhook_url = build_webhook_url

    webhook_config = {
      url: webhook_url,
      webhook_by_events: false,
      webhook_base64: true,
      events: %w[QRCODE_UPDATED MESSAGES_UPSERT MESSAGES_UPDATE CONNECTION_UPDATE SEND_MESSAGE]
    }

    url = "#{api_base_url}/webhook/set/#{instance_name}"
    Rails.logger.info "[EVOLUTION] Updating webhook config: #{url}"

    response = HTTParty.post(
      url,
      headers: api_headers,
      body: webhook_config.to_json
    )

    if response.success?
      Rails.logger.info "[EVOLUTION] Webhook updated successfully: #{response.body}"
    else
      Rails.logger.warn "[EVOLUTION] Webhook update failed (non-critical): #{response.body}"
    end
  rescue StandardError => e
    # Webhook update failure should not block settings update
    Rails.logger.warn "[EVOLUTION] Webhook update error (non-critical): #{e.message}"
  end

  def delete_instance
    return unless evolution_configured?

    # Try both endpoints just in case (logout/delete)
    # Usually delete is enough
    
    response = HTTParty.delete(
      "#{api_base_url}/instance/delete/#{instance_name}",
      headers: api_headers
    )

    if response.success?
      Rails.logger.info "[EVOLUTION] Instance deleted successfully: #{instance_name}"
      { success: true }
    else
      Rails.logger.error "[EVOLUTION] Delete instance failed: #{response.body}"
      { success: false, error: response.body }
    end
  end

  # Logout/Disconnect instance
  def logout
    unless evolution_configured?
      Rails.logger.error "[EVOLUTION] API not configured"
      return { success: false, error: 'Evolution API not configured' }
    end

    url = "#{api_base_url}/instance/logout/#{instance_name}"
    
    Rails.logger.info "[EVOLUTION] Logging out instance: #{url}"

    begin
      response = HTTParty.delete(url, headers: api_headers, timeout: 30)
      
      Rails.logger.info "[EVOLUTION] Logout response: #{response.code} - #{response.body}"

      if response.success?
        Rails.logger.info "[EVOLUTION] Instance logged out successfully"
        { success: true, message: 'Desconectado com sucesso' }
      else
        error_msg = response.parsed_response['message'] || response.body
        Rails.logger.error "[EVOLUTION] Logout failed: #{error_msg}"
        { success: false, error: error_msg }
      end
    rescue StandardError => e
      Rails.logger.error "[EVOLUTION] Logout exception: #{e.class} - #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Get QR code or Pairing Code
  def get_qr_code(phone_number: nil)
    unless evolution_configured?
      Rails.logger.error "[EVOLUTION] API not configured"
      return { success: false, error: 'Evolution API not configured' }
    end

    url = "#{api_base_url}/instance/connect/#{instance_name}"
    url += "?number=#{phone_number}" if phone_number.present?

    Rails.logger.info "[EVOLUTION] === QR CODE REQUEST ==="
    Rails.logger.info "[EVOLUTION] URL: #{url}"
    Rails.logger.info "[EVOLUTION] Phone number: #{phone_number.inspect}"

    begin
      response = HTTParty.get(url, headers: api_headers, timeout: 30)
      
      Rails.logger.info "[EVOLUTION] HTTP Status: #{response.code}"

      unless response.success?
        error_msg = "HTTP #{response.code}: #{response.message}"
        Rails.logger.error "[EVOLUTION] #{error_msg}"
        Rails.logger.error "[EVOLUTION] Response body: #{response.body}"
        return { success: false, error: error_msg }
      end

      parsed = response.parsed_response
      Rails.logger.info "[EVOLUTION] Raw response: #{parsed.inspect}"
      
      # Extrai o base64 QR Code
      qr_base64 = parsed['base64']
      
      # Se encontrou base64, garante que tem o prefixo correto
      if qr_base64.present?
        
        Rails.logger.info "[EVOLUTION] QR Code base64 length: #{qr_base64.length}"
        Rails.logger.info "[EVOLUTION] QR Code with prefix: #{qr_base64[0..80]}..."
      else
        Rails.logger.warn "[EVOLUTION] No QR code found in response"
        qr_base64 = nil
      end

      # Extrai Pairing Code
      pairing_code = parsed['pairingCode']
      Rails.logger.info "[EVOLUTION] Pairing code: #{pairing_code.inspect}" if pairing_code.present?

      result = {
        success: true,
        qr_code: qr_base64,
        pairing_code: pairing_code
      }
      
      Rails.logger.info "[EVOLUTION] === RESPONSE PREPARED ==="
      Rails.logger.info "[EVOLUTION] Has QR Code: #{qr_base64.present?}"
      Rails.logger.info "[EVOLUTION] Has Pairing Code: #{pairing_code.present?}"
      
      result
      
    rescue Net::ReadTimeout => e
      Rails.logger.error "[EVOLUTION] Timeout: #{e.message}"
      { success: false, error: 'Connection timeout to Evolution API' }
    rescue StandardError => e
      Rails.logger.error "[EVOLUTION] Exception: #{e.class} - #{e.message}"
      Rails.logger.error "[EVOLUTION] Backtrace: #{e.backtrace[0..3].join("\n")}"
      { success: false, error: "Error: #{e.message}" }
    end
  end

  # Get connection status
  def get_connection_status
    return { success: false, error: 'Evolution API not configured' } unless evolution_configured?

    response = HTTParty.get(
      "#{api_base_url}/instance/connectionState/#{instance_name}",
      headers: api_headers
    )

    if response.success?
      parsed = response.parsed_response
      state = parsed.dig('instance', 'state') || parsed['state']
      {
        success: true,
        connected: state == 'open',
        status: state
      }
    else
      { success: false, connected: false, status: 'unknown' }
    end
  end

  # Send media message
  def send_media(phone_number, message)
    return unless evolution_configured?
    return if phone_number.blank?

    formatted_number = phone_number.gsub(/^\+/, '')
    attachment = message.attachments.first

    return send_message(phone_number, message) unless attachment

    media_type = case attachment.file_type
                 when 'image' then 'sendMedia'
                 when 'video' then 'sendMedia'
                 when 'audio' then 'sendWhatsAppAudio'
                 else 'sendMedia'
                 end

    response = HTTParty.post(
      "#{api_base_url}/message/#{media_type}/#{instance_name}",
      headers: api_headers,
      body: {
        number: formatted_number,
        mediatype: attachment.file_type,
        media: attachment.file_url,
        caption: message.content
      }.to_json,
      timeout: 30
    )

    if response.success?
      response.parsed_response.dig('key', 'id')
    else
      Rails.logger.error "[EVOLUTION] Send media failed: #{response.body}"
      nil
    end
  end

  private

  def build_webhook_url
    base_url = GlobalConfig.get('FRONTEND_URL')['FRONTEND_URL'] || ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
    # Remove + from phone number for clean URL
    phone = whatsapp_channel.phone_number.to_s.gsub(/^\+/, '')
    "#{base_url}/webhooks/evolution/#{phone}"
  end
end
