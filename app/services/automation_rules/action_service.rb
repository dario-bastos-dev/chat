class AutomationRules::ActionService < ActionService
  # Terceiro segmento do parametro de `create_deal`, quando a regra pede que o
  # negocio nasca com o mesmo responsavel da conversa.
  CONVERSATION_ASSIGNEE = 'conversation_assignee'.freeze

  def initialize(rule, account, conversation)
    super(conversation)
    @rule = rule
    @account = account
    Current.executed_by = rule
  end

  def perform
    @rule.actions.each do |action|
      @conversation.reload
      action = action.with_indifferent_access
      begin
        send(action[:action_name], action[:action_params])
      rescue StandardError => e
        ChatwootExceptionTracker.new(e, account: @account).capture_exception
      end
    end
  ensure
    Current.reset
  end

  private

  def send_attachment(blob_ids)
    return if conversation_a_tweet?

    return unless @rule.files.attached?

    blobs = ActiveStorage::Blob.where(id: blob_ids)

    return if blobs.blank?

    params = { content: nil, private: false, attachments: blobs }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def send_webhook_event(webhook_url)
    payload = @conversation.webhook_data.merge(event: "automation_event.#{@rule.event_name}")
    WebhookJob.perform_later(webhook_url[0], payload)
  end

  def send_message(message)
    return if conversation_a_tweet?

    action_param = message[0]
    # A template is stored as a hash in the same action_params slot the plain text uses, so rules
    # created before templates were supported keep working untouched.
    return send_whatsapp_template(action_param) if action_param.is_a?(Hash)

    params = { content: action_param, private: false, content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  # Rules are account wide, so a template rule can match a conversation on any channel. Only WhatsApp
  # reads template_params; anywhere else the message would be delivered empty, so it is skipped.
  def send_whatsapp_template(action_param)
    template_params = action_param[:template_params]
    return if template_params.blank? || template_params[:name].blank?

    unless @conversation.inbox.channel.is_a?(Channel::Whatsapp)
      Rails.logger.info("[AUTOMATION] Rule #{@rule.id} skipped its template on non-WhatsApp inbox #{@conversation.inbox_id}")
      return
    end

    params = {
      content: render_liquid_variables(action_param[:content]),
      private: false,
      content_attributes: { automation_rule_id: @rule.id },
      template_params: render_liquid_deep(template_params)
    }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def add_private_note(message)
    return if conversation_a_tweet?

    params = { content: message[0], private: true, content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation.reload, params).perform
  end

  def send_email_to_team(params)
    teams = Team.where(id: params[0][:team_ids])

    teams.each do |team|
      break unless @account.within_email_rate_limit?

      TeamNotifications::AutomationNotificationMailer.conversation_creation(@conversation, team, params[0][:message])&.deliver_now
      @account.increment_email_sent_count
    end
  end

  def create_deal(params)
    pipeline_id, stage_id, assignee_option = params[0].to_s.split(':')

    pipeline = @account.pipelines.find_by(id: pipeline_id)
    return unless pipeline

    stage = if stage_id
              pipeline.stages.find_by(id: stage_id)
            else
              pipeline.stages.order(position: :asc).first
            end
    return unless stage

    contact = @conversation.contact
    return unless contact

    existing_deal = @account.deals.find_by(
      contact_id: contact.id,
      pipeline_id: pipeline.id,
      status: 'open'
    )

    if existing_deal
      conversation_deal = ConversationDeal.find_or_initialize_by(
        conversation_id: @conversation.id,
        deal_id: existing_deal.id
      )
      conversation_deal.is_primary = true
      conversation_deal.save!
    else
      Deals::Creator.new(
        account: @account,
        params: {
          title: contact.name,
          pipeline_id: pipeline.id,
          stage_id: stage.id,
          contact_id: contact.id,
          conversation_id: @conversation.id,
          assignee_id: (@conversation.assignee_id if assignee_option == CONVERSATION_ASSIGNEE)
        }
      ).perform
    end
  end

  def update_deal_info(params)
    action_param = params[0]&.with_indifferent_access
    return unless action_param

    deal = @conversation.deals.where(status: 'open').first
    deal ||= @account.deals.where(contact_id: @conversation.contact_id, status: 'open').first
    return unless deal

    params_to_update = {}
    if action_param[:title].present?
      params_to_update[:title] = render_liquid_variables(action_param[:title])
    end

    if action_param[:custom_attributes].present? && action_param[:custom_attributes].is_a?(Hash)
      processed_custom_attrs = {}
      action_param[:custom_attributes].each do |key, value|
        processed_custom_attrs[key] = render_liquid_variables(value.to_s)
      end
      params_to_update[:custom_attributes] = (deal.custom_attributes || {}).merge(processed_custom_attrs)
    end

    if params_to_update.present?
      Deals::Updater.new(deal: deal, params: params_to_update).perform
    end
  end

  def move_deal_stage(params)
    action_param = params[0]
    return unless action_param.present?

    if action_param.to_s.include?(':')
      pipeline_id, stage_id = action_param.split(':')
    else
      pipeline_id = action_param
      stage_id = nil
    end

    deal = @conversation.deals.where(status: 'open').first
    deal ||= @account.deals.where(contact_id: @conversation.contact_id, status: 'open').first
    return unless deal

    pipeline = @account.pipelines.find_by(id: pipeline_id)
    return unless pipeline

    stage = if stage_id
              pipeline.stages.find_by(id: stage_id)
            else
              pipeline.stages.order(position: :asc).first
            end
    return unless stage

    Deals::Updater.new(deal: deal, params: { stage_id: stage.id }).perform
  end

  def sync_deal_assignee(params)
    direction = params[0]
    return unless direction.present?

    deal = @conversation.deals.where(status: 'open').first
    deal ||= @account.deals.where(contact_id: @conversation.contact_id, status: 'open').first
    return unless deal

    if direction == 'conversation_to_deal'
      if @conversation.assignee_id != deal.assignee_id
        Deals::Updater.new(deal: deal, params: { assignee_id: @conversation.assignee_id }).perform
      end
    elsif direction == 'deal_to_conversation'
      if deal.assignee_id.present? && @conversation.assignee_id != deal.assignee_id
        @conversation.update!(assignee_id: deal.assignee_id)
      end
    end
  end

  def change_deal_status(params)
    status_val = params[0]
    return unless %w[won lost].include?(status_val)

    deal = @conversation.deals.where(status: 'open').first
    deal ||= @account.deals.where(contact_id: @conversation.contact_id, status: 'open').first
    return unless deal

    if status_val == 'won'
      deal.mark_as_won!
    elsif status_val == 'lost'
      deal.mark_as_lost!
    end
  end

  def add_deal_label(params)
    labels = params
    return unless labels.present?

    deal = @conversation.deals.where(status: 'open').first
    deal ||= @account.deals.where(contact_id: @conversation.contact_id, status: 'open').first
    return unless deal

    deal.add_labels(labels)
  end

  def remove_deal_label(params)
    labels_to_remove = params
    return unless labels_to_remove.present?

    deal = @conversation.deals.where(status: 'open').first
    deal ||= @account.deals.where(contact_id: @conversation.contact_id, status: 'open').first
    return unless deal

    remaining_labels = deal.label_list - labels_to_remove
    deal.update_labels(remaining_labels)
  end

  private

  # Template variables are nested inside processed_params (body, header, buttons), so the whole
  # structure is walked instead of only its top level.
  def render_liquid_deep(value)
    case value
    when String then render_liquid_variables(value)
    when Hash then value.transform_values { |nested| render_liquid_deep(nested) }
    when Array then value.map { |nested| render_liquid_deep(nested) }
    else value
    end
  end

  def render_liquid_variables(string)
    return string if string.blank?

    drops = {
      'contact' => ContactDrop.new(@conversation.contact),
      'agent' => UserDrop.new(@conversation.assignee),
      'conversation' => ConversationDrop.new(@conversation),
      'inbox' => InboxDrop.new(@conversation.inbox),
      'account' => AccountDrop.new(@account)
    }

    template = Liquid::Template.parse(string)
    template.render(drops)
  rescue Liquid::Error
    string
  end
end
