class Account::ConversationsExportJob < ApplicationJob
  queue_as :low

  def perform(account_id, user_id, params)
    @account = Account.find(account_id)
    Current.account = @account
    @params = params
    @account_user = @account.users.find(user_id)
    Current.user = @account_user
    @custom_attribute_keys = @account.custom_attribute_definitions.conversation_attribute.pluck(:attribute_key)

    headers = default_columns

    @user_timezone = params[:timezone] || @account_user.ui_settings['timezone'] || @account.reporting_timezone || 'UTC'
    user_locale = @account_user.ui_settings['locale'] || @account.locale || I18n.default_locale

    Time.use_zone(@user_timezone) do
      I18n.with_locale(user_locale) do
        generate_csv(headers)
      end
    end
    send_mail
  end

  private

  def generate_csv(headers)
    csv_data = CSV.generate do |csv|
      csv << headers.map { |h| I18n.t("conversations.export.#{h}", default: h.humanize) }
      conversations.find_each do |conversation|
        csv << headers.map { |header| get_value(conversation, header) }
      end
    end

    attach_export_file(csv_data)
  end

  def get_value(conversation, header)
    case header
    when 'inbox'
      conversation.inbox&.name
    when 'inbox_type'
      conversation.inbox&.channel_type
    when 'contact_name'
      conversation.contact&.name
    when 'contact_phone_number'
      conversation.contact&.phone_number
    when 'contact_email'
      conversation.contact&.email
    when 'agent_name'
      conversation.assignee&.name
    when 'team_name'
      conversation.team&.name
    when 'labels'
      conversation.label_list.join(', ')
    when 'created_at', 'last_activity_at'
      val = conversation.send(header)
      val ? I18n.l(val.in_time_zone(@user_timezone), format: :default) : ''
    when *@custom_attribute_keys
      conversation.custom_attributes[header]
    else
      conversation.send(header) if conversation.respond_to?(header)
    end
  end

  def conversations
    scope = if @params.present? && @params.with_indifferent_access[:payload].present? && @params.with_indifferent_access[:payload].any?
              result = ::Conversations::FilterService.new(@params.with_indifferent_access, @account_user, @account).perform
              result[:conversations]
            else
              # Using ConversationFinder to respect current status, assignee_type, etc.
              # Pass pagination out to get all records, or just unpaginate the underlying scope.
              finder = ConversationFinder.new(@account_user, @params.with_indifferent_access.merge(page: nil))
              finder.perform[:conversations].unscope(:limit, :offset)
            end
    scope.includes(:inbox, :contact, :assignee, :team, :taggings, :labels)
  end

  def attach_export_file(csv_data)
    return if csv_data.blank?

    @account.conversations_export.attach(
      io: StringIO.new(csv_data),
      filename: "#{@account.name}_#{@account.id}_conversations.csv",
      content_type: 'text/csv'
    )
  end

  def send_mail
    file_url = account_conversations_export_url
    mailer = AdministratorNotifications::AccountNotificationMailer.with(account: @account)
    mailer.conversation_export_complete(file_url, @account_user.email)&.deliver_later
  end

  def account_conversations_export_url
    Rails.application.routes.url_helpers.rails_blob_url(@account.conversations_export)
  end

  def default_columns
    standard_columns + @custom_attribute_keys
  end

  def standard_columns
    %w[id status assignee_id inbox contact_id display_id created_at last_activity_at priority contact_name contact_phone_number contact_email agent_name team_name labels]
  end
end
