class Api::V1::Accounts::InboxMessageTemplatesController < Api::V1::Accounts::BaseController
  EDIT_INTERVAL = 24.hours

  before_action :fetch_inbox
  before_action :validate_whatsapp_cloud_channel

  def create
    result = @inbox.channel.provider_service.create_message_template(template_params)
    return render_creation_failure(result) unless result[:success]

    store_template_media
    sync_templates
    render json: { template: result.except(:success) }, status: :created
  end

  def update
    template = find_synced_template
    return render json: { error: 'Template not found' }, status: :not_found if template.blank?
    return render json: { error: 'Only marketing templates can be edited' }, status: :unprocessable_entity unless marketing?(template)
    return render json: { error: edit_throttled_message }, status: :unprocessable_entity if edit_throttled?(template)

    result = @inbox.channel.provider_service.update_message_template(template['id'], template_params)
    return render_creation_failure(result) unless result[:success]

    throttle_next_edit(template)
    store_template_media
    sync_templates
    render json: { message: 'Template updated successfully' }
  end

  def destroy
    result = @inbox.channel.provider_service.delete_message_template(params[:name])
    return render json: { error: 'Template deletion failed' }, status: :unprocessable_entity unless result[:success]

    discard_template_media
    sync_templates
    render json: { message: 'Template deleted successfully' }
  end

  # The file is uploaded to Meta for the approval sample and kept here as well: Meta requires the
  # media on every send but only stores the sample, behind a signed URL that expires.
  # `header_format` and not `format`: the api namespace declares `defaults: { format: 'json' }`, and
  # route defaults win over the request body, so a `format` field would always arrive as "json".
  def media
    result = @inbox.channel.provider_service.upload_template_media(params[:file], params[:header_format].to_s.upcase)
    return render json: { error: result[:error] }, status: :unprocessable_entity unless result[:success]

    render json: { handle: result[:handle], blob_id: stored_media_blob_id }
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

  # Resolving the Meta id from the synced list — rather than trusting one sent by
  # the client — keeps an edit scoped to templates this inbox actually owns.
  def find_synced_template
    Array(@inbox.channel.message_templates).find do |template|
      template['name'] == params[:name] &&
        (params[:language].blank? || template['language'].to_s.casecmp?(params[:language].to_s))
    end
  end

  def marketing?(template)
    template['category'].to_s.casecmp?('MARKETING')
  end

  def edit_throttle_key(template)
    format(Redis::Alfred::WHATSAPP_TEMPLATE_EDIT_THROTTLE, channel_id: @inbox.channel.id, template_id: template['id'])
  end

  def edit_throttled?(template)
    Redis::Alfred.get(edit_throttle_key(template)).present?
  end

  def throttle_next_edit(template)
    Redis::Alfred.set(edit_throttle_key(template), Time.current.iso8601, ex: EDIT_INTERVAL.to_i)
  end

  def edit_throttled_message
    "This template was edited in the last #{EDIT_INTERVAL.inspect}. Try again later."
  end

  def stored_media_blob_id
    params[:file].rewind
    ActiveStorage::Blob.create_and_upload!(
      io: params[:file],
      filename: params[:file].original_filename,
      content_type: params[:file].content_type
    ).signed_id
  end

  # Attached only after Meta accepts the template: a rejected creation must not leave media behind
  # for a template that does not exist.
  def store_template_media
    blob = media_blob
    return if blob.blank?

    name, language = template_identity
    return if name.blank? || language.blank?

    record = WhatsappTemplateMedia.find_or_initialize_by(account_id: Current.account.id, template_name: name, language: language)
    record.file.attach(blob)
    record.save!
  end

  def media_blob
    signed_id = params.dig(:template, :header, :media_blob_id).presence
    return if signed_id.blank?

    ActiveStorage::Blob.find_signed(signed_id)
  end

  # Meta deletes a template by name, across every language, so the stored media follows. Kept when a
  # sibling inbox on another WABA still lists the template, since the media is shared by the account.
  def discard_template_media
    return if template_used_by_other_inbox?

    WhatsappTemplateMedia.where(account_id: Current.account.id, template_name: params[:name]).destroy_all
  end

  def template_used_by_other_inbox?
    Current.account.inboxes.where.not(id: @inbox.id).any? do |inbox|
      inbox.channel.is_a?(Channel::Whatsapp) &&
        Array(inbox.channel.message_templates).any? { |template| template['name'] == params[:name] }
    end
  end

  def template_identity
    [
      params[:name].presence || template_params[:name],
      params[:language].presence || template_params[:language]
    ]
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
