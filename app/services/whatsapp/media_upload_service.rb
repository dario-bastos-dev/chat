# Uploads a media file through Meta's Resumable Upload API and returns the
# `header_handle` required to create a template with a media header.
#
# Template creation does not accept a plain URL: the file has to be uploaded to
# the Meta *app* (not the WABA) first, in two steps.
#   1. POST /{app_id}/uploads         -> upload session id
#   2. POST /{upload_session_id}      -> file handle ("h")
#
# Step 2 is the odd one out in this codebase: it posts raw bytes instead of JSON
# and authenticates with `OAuth <token>` rather than `Bearer <token>`.
class Whatsapp::MediaUploadService
  SUPPORTED_TYPES = {
    'IMAGE' => %w[image/jpeg image/png].freeze,
    'VIDEO' => %w[video/mp4 video/3gpp].freeze,
    'DOCUMENT' => %w[application/pdf].freeze
  }.freeze

  MAX_FILE_SIZES = {
    'IMAGE' => 5.megabytes,
    'VIDEO' => 16.megabytes,
    'DOCUMENT' => 100.megabytes
  }.freeze

  class UploadError < StandardError; end

  def initialize(whatsapp_channel)
    @whatsapp_channel = whatsapp_channel
  end

  def upload(file, format)
    validate!(file, format)
    session_id = create_upload_session(file)
    { success: true, handle: upload_file_bytes(session_id, file) }
  rescue UploadError => e
    { success: false, error: e.message }
  end

  private

  def validate!(file, format)
    raise UploadError, 'WhatsApp App ID is not configured for this installation' if app_id.blank?
    raise UploadError, "Unsupported header format: #{format}" unless SUPPORTED_TYPES.key?(format)

    unless SUPPORTED_TYPES[format].include?(file.content_type)
      raise UploadError, "#{format} headers accept only #{SUPPORTED_TYPES[format].join(', ')}"
    end

    max_size = MAX_FILE_SIZES[format]
    raise UploadError, "#{format} files must be smaller than #{max_size / 1.megabyte}MB" if file.size > max_size
  end

  def create_upload_session(file)
    response = HTTParty.post(
      "#{api_base_path}/#{api_version}/#{app_id}/uploads",
      query: { file_length: file.size, file_type: file.content_type, access_token: access_token }
    )
    raise UploadError, "Could not start the media upload: #{response.body}" unless response.success?

    response['id'].presence || raise(UploadError, 'Meta did not return an upload session id')
  end

  def upload_file_bytes(session_id, file)
    response = HTTParty.post(
      "#{api_base_path}/#{api_version}/#{session_id}",
      headers: { 'Authorization' => "OAuth #{access_token}", 'file_offset' => '0' },
      body: file.read
    )
    raise UploadError, "Could not upload the media file: #{response.body}" unless response.success?

    response['h'].presence || raise(UploadError, 'Meta did not return a file handle')
  end

  def access_token
    @whatsapp_channel.provider_config['api_key']
  end

  def app_id
    GlobalConfigService.load('WHATSAPP_APP_ID', '')
  end

  def api_version
    GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')
  end

  def api_base_path
    ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
  end
end
