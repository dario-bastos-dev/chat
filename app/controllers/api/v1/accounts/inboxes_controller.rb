class Api::V1::Accounts::InboxesController < Api::V1::Accounts::BaseController
  include Api::V1::InboxesHelper
  before_action :fetch_inbox, except: [:index, :create]
  before_action :fetch_agent_bot, only: [:set_agent_bot]
  before_action :validate_limit, only: [:create]
  # we are already handling the authorization in fetch inbox
  before_action :check_authorization, except: [:show]
  before_action :validate_whatsapp_cloud_channel, only: [:health]


  include Api::V1::Accounts::Concerns::WhatsappHealthManagement

  def index
    @inboxes = policy_scope(Current.account.inboxes)
               .includes(:channel, :portal, :working_hours, { avatar_attachment: :blob })
               .order_by_name
  end

  def show; end

  # Deprecated: This API will be removed in 2.7.0
  def assignable_agents
    @assignable_agents = @inbox.assignable_agents
  end

  def campaigns
    @campaigns = @inbox.campaigns
  end

  def avatar
    @inbox.avatar.attachment.destroy! if @inbox.avatar.attached?
    head :ok
  end

  def create
    ActiveRecord::Base.transaction do
      channel = create_channel
      @inbox = Current.account.inboxes.build(
        {
          name: inbox_name(channel),
          channel: channel
        }.merge(
          permitted_params.except(:channel)
        )
      )
      @inbox.save!
    end
  end

  def update
    inbox_params = permitted_params.except(:channel, :csat_config)
    inbox_params[:csat_config] = format_csat_config(permitted_params[:csat_config]) if permitted_params[:csat_config].present?
    @inbox.update!(inbox_params)
    update_inbox_working_hours
    update_channel if channel_update_required?
  end

  def agent_bot
    @agent_bot = @inbox.agent_bot
  end

  def set_agent_bot
    if @agent_bot
      agent_bot_inbox = @inbox.agent_bot_inbox || AgentBotInbox.new(inbox: @inbox)
      agent_bot_inbox.agent_bot = @agent_bot
      agent_bot_inbox.save!
    elsif @inbox.agent_bot_inbox.present?
      @inbox.agent_bot_inbox.destroy!
    end
    head :ok
  end

  def reset_secret
    return head :not_found unless @inbox.api?

    @inbox.channel.reset_secret!
  end

  def destroy
    ::DeleteObjectJob.perform_later(@inbox, Current.user, request.ip) if @inbox.present?
    render status: :ok, json: { message: I18n.t('messages.inbox_deletetion_response') }
  end

  def sync_templates
    return render status: :unprocessable_entity, json: { error: 'Template sync is only available for WhatsApp channels' } unless whatsapp_channel?

    trigger_template_sync
    render status: :ok, json: { message: 'Template sync initiated successfully' }
  rescue StandardError => e
    render status: :internal_server_error, json: { error: e.message }
  end

  def health
    health_data = Whatsapp::HealthService.new(@inbox.channel).fetch_health_status
    render json: health_data
  rescue StandardError => e
    Rails.logger.error "[INBOX HEALTH] Error fetching health data: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def evolution_qrcode
    Rails.logger.info "[EVOLUTION CONTROLLER] === QR CODE REQUEST ==="
    Rails.logger.info "[EVOLUTION CONTROLLER] Inbox ID: #{params[:id]}, Account ID: #{params[:account_id]}"
    
    unless evolution_channel?
      Rails.logger.warn "[EVOLUTION CONTROLLER] Not an Evolution channel"
      return render json: { error: 'Not an Evolution channel', success: false }, status: :bad_request
    end
    
    Rails.logger.info "[EVOLUTION CONTROLLER] Phone number param: #{params[:number]}"
    Rails.logger.info "[EVOLUTION CONTROLLER] Channel: #{@inbox.channel.class.name}, Provider: #{@inbox.channel&.provider}"
    
    result = @inbox.channel.provider_service.get_qr_code(phone_number: params[:number])
    
    Rails.logger.info "[EVOLUTION CONTROLLER] Result: success=#{result[:success]}, has_qr=#{result[:qr_code].present?}, has_pairing=#{result[:pairing_code].present?}"
    
    render json: result
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION CONTROLLER] ❌ Exception: #{e.class} - #{e.message}"
    Rails.logger.error "[EVOLUTION CONTROLLER] Backtrace:\n#{e.backtrace[0..5].join("\n")}"
    render json: { error: e.message, success: false }, status: :internal_server_error
  end

  def evolution_status
    return render json: { error: 'Not an Evolution channel' }, status: :bad_request unless evolution_channel?

    result = @inbox.channel.provider_service.get_connection_status
    render json: result
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION] Error fetching status: #{e.message}"
    render json: { error: e.message, success: false, connected: false }, status: :unprocessable_entity
  end

  def evolution_create_instance
    return render json: { error: 'Not an Evolution channel' }, status: :bad_request unless evolution_channel?

    result = @inbox.channel.provider_service.create_instance
    render json: result
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION] Error creating instance: #{e.message}"
    render json: { error: e.message, success: false }, status: :unprocessable_entity
  end

  def evolution_disconnect
    return render json: { error: 'Not an Evolution channel', success: false }, status: :bad_request unless evolution_channel?

    Rails.logger.info "[EVOLUTION CONTROLLER] Disconnecting instance for inbox #{@inbox.id}"
    
    result = @inbox.channel.provider_service.logout
    
    Rails.logger.info "[EVOLUTION CONTROLLER] Disconnect result: #{result.inspect}"
    render json: result
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION CONTROLLER] Error disconnecting: #{e.class} - #{e.message}"
    render json: { error: e.message, success: false }, status: :internal_server_error
  end

  def evolution_diagnostics
    return render json: { error: 'Not an Evolution channel' }, status: :bad_request unless evolution_channel?

    service = @inbox.channel.provider_service
    
    diagnostics = {
      inbox_id: @inbox.id,
      inbox_name: @inbox.name,
      phone_number: @inbox.phone_number,
      provider: @inbox.channel.provider,
      
      api_configured: service.evolution_configured?,
      api_url: service.api_base_url,
      api_token_present: service.api_token.present?,
      
      instance_name: service.instance_name,
      
      evolution_api_urls: {
        qr_code: "#{service.api_base_url}/instance/connect/#{service.instance_name}",
        pairing_code_example: "#{service.api_base_url}/instance/connect/#{service.instance_name}?number=5527997774194",
        status: "#{service.api_base_url}/instance/connectionState/#{service.instance_name}",
        create_instance: "#{service.api_base_url}/instance/create",
        update_settings: "#{service.api_base_url}/settings/set/#{service.instance_name}"
      },
      
      chatwoot_api_urls: {
        qr_code_endpoint: "GET #{request.base_url}/api/v1/accounts/#{Current.account.id}/inboxes/#{@inbox.id}/evolution_qrcode",
        pairing_code_endpoint: "GET #{request.base_url}/api/v1/accounts/#{Current.account.id}/inboxes/#{@inbox.id}/evolution_qrcode?number=5527997774194",
        status_endpoint: "GET #{request.base_url}/api/v1/accounts/#{Current.account.id}/inboxes/#{@inbox.id}/evolution_status"
      }
    }
    
    render json: diagnostics
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION DIAGNOSTICS] Error: #{e.class} - #{e.message}"
    render json: { error: e.message }, status: :internal_server_error
  end

  # --- Evolution GO Actions ---

  def evolution_go_qrcode
    return render json: { error: 'Not an Evolution GO channel', success: false }, status: :bad_request unless evolution_go_channel?

    result = @inbox.channel.provider_service.get_qr_code
    render json: result
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] QR code error: #{e.message}"
    render json: { error: e.message, success: false }, status: :internal_server_error
  end

  def evolution_go_pairing
    return render json: { error: 'Not an Evolution GO channel', success: false }, status: :bad_request unless evolution_go_channel?

    result = @inbox.channel.provider_service.get_pairing_code(phone_number: params[:number])
    render json: result
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] Pairing code error: #{e.message}"
    render json: { error: e.message, success: false }, status: :internal_server_error
  end

  def evolution_go_status
    return render json: { error: 'Not an Evolution GO channel' }, status: :bad_request unless evolution_go_channel?

    result = @inbox.channel.provider_service.get_connection_status
    render json: result
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] Status error: #{e.message}"
    render json: { error: e.message, success: false, connected: false }, status: :unprocessable_entity
  end

  def evolution_go_create_instance
    return render json: { error: 'Not an Evolution GO channel' }, status: :bad_request unless evolution_go_channel?

    result = @inbox.channel.provider_service.create_instance
    render json: result
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] Create instance error: #{e.message}"
    render json: { error: e.message, success: false }, status: :unprocessable_entity
  end

  def evolution_go_disconnect
    return render json: { error: 'Not an Evolution GO channel', success: false }, status: :bad_request unless evolution_go_channel?

    result = @inbox.channel.provider_service.logout
    render json: result
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION_GO] Disconnect error: #{e.message}"
    render json: { error: e.message, success: false }, status: :internal_server_error
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:id])
    authorize @inbox, :show?
  end

  def fetch_agent_bot
    @agent_bot = AgentBot.accessible_to(Current.account).find(params[:agent_bot]) if params[:agent_bot]
  end

  def create_channel
    return unless allowed_channel_types.include?(permitted_params[:channel][:type])

    account_channels_method.create!(permitted_params(channel_type_from_params::EDITABLE_ATTRS)[:channel].except(:type))
  end

  def allowed_channel_types
    %w[web_widget api email line telegram whatsapp sms]
  end

  def update_inbox_working_hours
    @inbox.update_working_hours(params.permit(working_hours: Inbox::OFFISABLE_ATTRS)[:working_hours]) if params[:working_hours]
  end

  def update_channel
    channel_attributes = get_channel_attributes(@inbox.channel_type)
    return if permitted_params(channel_attributes)[:channel].blank?

    validate_and_update_email_channel(channel_attributes) if @inbox.inbox_type == 'Email'

    reauthorize_and_update_channel(channel_attributes)
    update_channel_feature_flags
  end

  def channel_update_required?
    permitted_params(get_channel_attributes(@inbox.channel_type))[:channel].present?
  end

  def validate_and_update_email_channel(channel_attributes)
    validate_email_channel(channel_attributes)
  rescue StandardError => e
    render json: { message: e }, status: :unprocessable_entity and return
  end

  def reauthorize_and_update_channel(channel_attributes)
    @inbox.channel.reauthorized! if @inbox.channel.respond_to?(:reauthorized!)
    @inbox.channel.update!(permitted_params(channel_attributes)[:channel])
  end

  def update_channel_feature_flags
    return unless @inbox.web_widget?
    return unless permitted_params(Channel::WebWidget::EDITABLE_ATTRS)[:channel].key? :selected_feature_flags

    @inbox.channel.selected_feature_flags = permitted_params(Channel::WebWidget::EDITABLE_ATTRS)[:channel][:selected_feature_flags]
    @inbox.channel.save!
  end

  def format_csat_config(config)
    formatted = {
      'display_type' => config['display_type'] || 'emoji',
      'message' => config['message'] || '',
      :survey_rules => {
        'operator' => config.dig('survey_rules', 'operator') || 'contains',
        'values' => config.dig('survey_rules', 'values') || []
      },
      'button_text' => config['button_text'] || 'Please rate us',
      'language' => config['language'] || 'en'
    }
    format_template_config(config, formatted)
    formatted
  end

  def format_template_config(config, formatted)
    formatted['template'] = config['template'] if config['template'].present?
  end

  def inbox_attributes
    [:name, :avatar, :greeting_enabled, :greeting_message, :enable_email_collect, :csat_survey_enabled,
     :enable_auto_assignment, :working_hours_enabled, :out_of_office_message, :timezone, :allow_messages_after_resolved,
     :lock_to_single_conversation, :portal_id, :sender_name_type, :business_name, :unread_reset_mode,
     { csat_config: [:display_type, :message, :button_text, :language,
                     { survey_rules: [:operator, { values: [] }],
                       template: [:name, :template_id, :friendly_name, :content_sid, :approval_sid, :created_at, :language, :status] }] }]
  end

  def permitted_params(channel_attributes = [])
    # We will remove this line after fixing https://linear.app/chatwoot/issue/CW-1567/null-value-passed-as-null-string-to-backend
    params.each { |k, v| params[k] = params[k] == 'null' ? nil : v }
    params.permit(*inbox_attributes, channel: [:type, *channel_attributes])
  end

  def channel_type_from_params
    {
      'web_widget' => Channel::WebWidget,
      'api' => Channel::Api,
      'email' => Channel::Email,
      'line' => Channel::Line,
      'telegram' => Channel::Telegram,
      'whatsapp' => Channel::Whatsapp,
      'sms' => Channel::Sms
    }[permitted_params[:channel][:type]]
  end

  def get_channel_attributes(channel_type)
    channel_type.constantize.const_defined?(:EDITABLE_ATTRS) ? channel_type.constantize::EDITABLE_ATTRS.presence : []
  end
  def whatsapp_channel?
    @inbox.whatsapp? || (@inbox.twilio? && @inbox.channel.whatsapp?)
  end

  def evolution_channel?
    @inbox&.channel.is_a?(Channel::Whatsapp) && @inbox.channel&.provider == 'evolution'
  end

  def evolution_go_channel?
    @inbox&.channel.is_a?(Channel::Whatsapp) && @inbox.channel&.provider == 'evolution_go'
  end

  def trigger_template_sync
    if @inbox.whatsapp?
      Channels::Whatsapp::TemplatesSyncJob.perform_later(@inbox.channel)
    elsif @inbox.twilio? && @inbox.channel.whatsapp?
      Channels::Twilio::TemplatesSyncJob.perform_later(@inbox.channel)
    end
  end
end

Api::V1::Accounts::InboxesController.prepend_mod_with('Api::V1::Accounts::InboxesController')
