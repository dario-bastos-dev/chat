# Reads and updates the WhatsApp business profile shown to customers (about text, description,
# address, email, websites, category and profile picture).
# https://developers.facebook.com/documentation/business-messaging/whatsapp/reference/whatsapp-business-phone-number/whatsapp-business-profile-api
#
# The read and write payloads are not symmetrical: Meta returns `profile_picture_url` on GET but
# only accepts `profile_picture_handle` (from the Resumable Upload API) on POST.
class Whatsapp::BusinessProfileService
  FIELDS = %w[about address description email profile_picture_url websites vertical].freeze

  VERTICALS = %w[
    OTHER AUTO BEAUTY APPAREL EDU ENTERTAIN EVENT_PLAN FINANCE GROCERY GOVT HOTEL HEALTH
    NONPROFIT PROF_SERVICES RETAIL TRAVEL RESTAURANT ALCOHOL ONLINE_GAMBLING PHYSICAL_GAMBLING OTC_DRUGS
  ].freeze

  class ApiError < StandardError; end

  def initialize(channel)
    @channel = channel
  end

  def fetch
    response = HTTParty.get(profile_url, headers: headers, query: { fields: FIELDS.join(',') })
    raise ApiError, error_message(response) unless response.success?

    Array.wrap(response.parsed_response['data']).first || {}
  end

  def update!(attributes)
    response = HTTParty.post(
      profile_url,
      headers: headers,
      body: attributes.merge(messaging_product: 'whatsapp').to_json
    )
    raise ApiError, error_message(response) unless response.success?

    # Meta already accepted the write. A transient failure reading it back must not be reported as a
    # failed save, or the admin retries an update that already went through (re-uploading the picture).
    begin
      fetch
    rescue ApiError => e
      Rails.logger.warn("[WHATSAPP] Business profile saved but could not be read back: #{e.message}")
      {}
    end
  end

  private

  def profile_url
    base_path = ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
    api_version = GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')

    "#{base_path}/#{api_version}/#{@channel.provider_config['phone_number_id']}/whatsapp_business_profile"
  end

  def headers
    { 'Authorization' => "Bearer #{@channel.provider_config['api_key']}", 'Content-Type' => 'application/json' }
  end

  def error_message(response)
    parsed = response.parsed_response
    (parsed.is_a?(Hash) && parsed.dig('error', 'message')) || "WhatsApp business profile request failed with status #{response.code}"
  end
end
