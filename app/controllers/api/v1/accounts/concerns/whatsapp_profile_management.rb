module Api::V1::Accounts::Concerns::WhatsappProfileManagement
  extend ActiveSupport::Concern

  # Meta rejects an empty `about` and refuses to unset `vertical` once it has been assigned,
  # so a cleared field is dropped from the payload instead of being sent as a blank value.
  NON_CLEARABLE_PROFILE_FIELDS = %i[about vertical].freeze

  included do
    before_action :validate_whatsapp_cloud_channel, only: [:whatsapp_profile, :update_whatsapp_profile]
  end

  def whatsapp_profile
    render json: { payload: business_profile_service.fetch, verticals: Whatsapp::BusinessProfileService::VERTICALS }
  rescue Whatsapp::BusinessProfileService::ApiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update_whatsapp_profile
    attributes = whatsapp_profile_params
    attributes[:profile_picture_handle] = upload_profile_picture! if params[:profile_picture].present?

    render json: { payload: business_profile_service.update!(attributes) }
  rescue Whatsapp::BusinessProfileService::ApiError, Whatsapp::MediaUploadService::UploadError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def business_profile_service
    Whatsapp::BusinessProfileService.new(@inbox.channel)
  end

  def whatsapp_profile_params
    attributes = params.permit(:about, :address, :description, :email, :vertical, websites: []).to_h.symbolize_keys
    attributes[:websites] = attributes[:websites].compact_blank if attributes.key?(:websites)
    attributes.reject { |key, value| NON_CLEARABLE_PROFILE_FIELDS.include?(key) && value.blank? }
  end

  def upload_profile_picture!
    result = Whatsapp::MediaUploadService.new(@inbox.channel).upload(params[:profile_picture], 'IMAGE')
    raise Whatsapp::MediaUploadService::UploadError, result[:error] unless result[:success]

    result[:handle]
  end
end
