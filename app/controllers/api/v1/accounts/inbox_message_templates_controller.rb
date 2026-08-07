class Api::V1::Accounts::InboxMessageTemplatesController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox
  before_action :validate_whatsapp_cloud_channel

  def create
    result = @inbox.channel.provider_service.create_message_template(template_params)
    return render_creation_failure(result) unless result[:success]

    sync_templates
    render json: { template: result.except(:success) }, status: :created
  end

  def destroy
    result = @inbox.channel.provider_service.delete_message_template(params[:name])
    return render json: { error: 'Template deletion failed' }, status: :unprocessable_entity unless result[:success]

    sync_templates
    render json: { message: 'Template deleted successfully' }
  end

  def media
    result = @inbox.channel.provider_service.upload_template_media(params[:file], params[:format].to_s.upcase)
    return render json: { error: result[:error] }, status: :unprocessable_entity unless result[:success]

    render json: { handle: result[:handle] }
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    authorize @inbox, :update?
  end

  def validate_whatsapp_cloud_channel
    return if @inbox.channel.is_a?(Channel::Whatsapp) && @inbox.channel.provider == 'whatsapp_cloud'

    render json: { error: 'Template management is only available for WhatsApp Cloud API channels' }, status: :bad_request
  end

  def sync_templates
    Channels::Whatsapp::TemplatesSyncJob.perform_later(@inbox.channel)
  end

  def template_params
    params.require(:template).permit(
      :name, :category, :language,
      header: [:text, :format, :media_handle, { example: [] }],
      body: [:text, { example: [] }],
      footer: [:text],
      buttons: [:type, :text, :url, :phone_number, { example: [] }]
    ).to_h.deep_symbolize_keys
  end

  def render_creation_failure(result)
    whatsapp_error = parse_whatsapp_error(result[:response_body])

    render json: {
      error: whatsapp_error[:user_message] || result[:error],
      details: whatsapp_error[:technical_details]
    }, status: :unprocessable_entity
  end

  def parse_whatsapp_error(response_body)
    return { user_message: nil, technical_details: nil } if response_body.blank?

    error_data = JSON.parse(response_body)
    whatsapp_error = error_data['error'] || {}

    {
      user_message: whatsapp_error['error_user_msg'] || whatsapp_error['message'],
      technical_details: {
        code: whatsapp_error['code'],
        subcode: whatsapp_error['error_subcode'],
        title: whatsapp_error['error_user_title']
      }.compact
    }
  rescue JSON::ParserError
    { user_message: nil, technical_details: response_body }
  end
end
