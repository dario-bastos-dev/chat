# Job to fetch and set contact avatar from Evolution API
# Strategy:
# 1. Try to fetch profile picture URL from Evolution API (high quality)
# 2. Fallback to jpegThumbnail from message payload (low quality thumbnail)
class Webhooks::EvolutionContactAvatarJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 5.seconds, attempts: 2

  def perform(contact_id, inbox_id, remote_jid, jpeg_thumbnail_bytes = nil)
    @contact = Contact.find_by(id: contact_id)
    return if @contact.blank?

    # Skip if contact already has an avatar
    return if @contact.avatar.attached?

    @inbox = Inbox.find_by(id: inbox_id)
    return if @inbox.blank?

    Rails.logger.info "[EVOLUTION AVATAR] Starting avatar fetch for Contact #{contact_id} (#{remote_jid})"

    # Strategy 1: Fetch profile picture from Evolution API
    if fetch_profile_picture_from_api(remote_jid)
      Rails.logger.info "[EVOLUTION AVATAR] ✅ Avatar set from Evolution API for Contact #{contact_id}"
      return
    end

    # Strategy 2: Use jpegThumbnail from message payload
    if jpeg_thumbnail_bytes.present? && attach_from_thumbnail_bytes(jpeg_thumbnail_bytes)
      Rails.logger.info "[EVOLUTION AVATAR] ✅ Avatar set from jpegThumbnail for Contact #{contact_id}"
      return
    end

    Rails.logger.info "[EVOLUTION AVATAR] No avatar source available for Contact #{contact_id}"
  end

  private

  def fetch_profile_picture_from_api(remote_jid)
    channel = @inbox.channel
    return false unless channel.is_a?(Channel::Whatsapp) && channel.provider == 'evolution'

    # Build Evolution API service to access config
    api_base_url = GlobalConfig.get('EVOLUTION_API_URL')['EVOLUTION_API_URL'] || ENV.fetch('EVOLUTION_API_URL', nil)
    api_token = GlobalConfig.get('EVOLUTION_API_TOKEN')['EVOLUTION_API_TOKEN'] || ENV.fetch('EVOLUTION_API_TOKEN', nil)

    return false if api_base_url.blank? || api_token.blank?

    api_base_url = api_base_url.chomp('/')
    instance_name = channel.phone_number&.gsub(/^\+/, '')

    # Extract the phone number from JID
    number = remote_jid.to_s.split('@').first

    Rails.logger.info "[EVOLUTION AVATAR] Fetching profile picture from API for #{number}"

    response = HTTParty.post(
      "#{api_base_url}/chat/fetchProfilePictureUrl/#{instance_name}",
      headers: {
        'Content-Type' => 'application/json',
        'apikey' => api_token
      },
      body: { number: number }.to_json,
      timeout: 10
    )

    if response.success?
      parsed = response.parsed_response
      picture_url = parsed['profilePictureUrl'] || parsed['profilePicture'] || parsed.dig('data', 'profilePictureUrl')

      if picture_url.present?
        Rails.logger.info "[EVOLUTION AVATAR] Profile picture URL found: #{picture_url.truncate(80)}"
        return attach_from_url(picture_url)
      end
    end

    Rails.logger.info "[EVOLUTION AVATAR] No profile picture from API (status: #{response.code})"
    false
  rescue StandardError => e
    Rails.logger.warn "[EVOLUTION AVATAR] API fetch failed: #{e.message}"
    false
  end

  def attach_from_url(url)
    downloaded_io = URI.open(url, open_timeout: 10, read_timeout: 15)

    @contact.avatar.attach(
      io: downloaded_io,
      filename: "avatar_#{@contact.id}.jpg",
      content_type: 'image/jpeg'
    )

    @contact.save!
    true
  rescue StandardError => e
    Rails.logger.warn "[EVOLUTION AVATAR] Failed to attach from URL: #{e.message}"
    false
  end

  def attach_from_thumbnail_bytes(thumbnail_bytes)
    # thumbnail_bytes can be:
    # 1. A Hash with numeric string keys ("0" => 255, "1" => 216, ...) - from Evolution API payload
    # 2. An Array of byte values
    # 3. A Base64 encoded string

    binary_data = convert_to_binary(thumbnail_bytes)
    return false if binary_data.blank?

    # Validate it's a JPEG (starts with FF D8)
    unless binary_data.bytes[0] == 0xFF && binary_data.bytes[1] == 0xD8
      Rails.logger.warn "[EVOLUTION AVATAR] Thumbnail is not a valid JPEG"
      return false
    end

    Rails.logger.info "[EVOLUTION AVATAR] Attaching thumbnail (#{binary_data.bytesize} bytes)"

    @contact.avatar.attach(
      io: StringIO.new(binary_data),
      filename: "avatar_#{@contact.id}.jpg",
      content_type: 'image/jpeg'
    )

    @contact.save!
    true
  rescue StandardError => e
    Rails.logger.warn "[EVOLUTION AVATAR] Failed to attach thumbnail: #{e.message}"
    false
  end

  def convert_to_binary(data)
    case data
    when Hash
      # Hash with numeric keys: {"0" => 255, "1" => 216, ...}
      # Sort by numeric key and extract byte values
      sorted_bytes = data.sort_by { |k, _| k.to_i }.map { |_, v| v.to_i }
      sorted_bytes.pack('C*')
    when Array
      # Array of byte values: [255, 216, 255, ...]
      data.map(&:to_i).pack('C*')
    when String
      if data.match?(/^[A-Za-z0-9+\/\n\r]+=*$/) || data.start_with?('data:')
        # Base64 encoded
        clean = data.sub(/^data:.*?;base64,/, '')
        Base64.decode64(clean)
      else
        # Raw binary string
        data
      end
    else
      nil
    end
  rescue StandardError => e
    Rails.logger.warn "[EVOLUTION AVATAR] Failed to convert thumbnail data: #{e.message}"
    nil
  end
end
