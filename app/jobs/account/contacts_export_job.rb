class Account::ContactsExportJob < ApplicationJob
  queue_as :low

  def perform(account_id, user_id, column_names, params)
    @account = Account.find(account_id)
    Current.account = @account
    @params = params
    @account_user = @account.users.find(user_id)
    Current.user = @account_user
    @custom_attribute_keys = @account.custom_attribute_definitions.contact_attribute.pluck(:attribute_key)

    headers = valid_headers(column_names)
    generate_csv(headers)
    send_mail
  end

  private

  def generate_csv(headers)
    csv_data = CSV.generate do |csv|
      csv << headers.map { |h| I18n.t("contacts.export.#{h}", default: h.humanize) }
      contacts.find_each do |contact|
        csv << headers.map { |header| get_value(contact, header) }
      end
    end

    attach_export_file(csv_data)
  end

  def get_value(contact, header)
    case header
    when 'labels'
      contact.label_list.join(', ')
    when 'created_at', 'last_activity_at'
      contact.send(header)&.strftime('%Y-%m-%d %H:%M:%S')
    when *Contact.column_names
      contact.send(header)
    when *@custom_attribute_keys
      contact.custom_attributes[header]
    else
      contact.additional_attributes[header] || ''
    end
  end

  def contacts
    scope = if @params.present? && @params.with_indifferent_access[:payload].present? && @params.with_indifferent_access[:payload].any?
              result = ::Contacts::FilterService.new(@account, @account_user, @params.with_indifferent_access).perform
              result[:contacts]
            elsif @params.with_indifferent_access[:label].present?
              @account.contacts.resolved_contacts(use_crm_v2: @account.feature_enabled?('crm_v2')).tagged_with(@params.with_indifferent_access[:label], any: true)
            else
              @account.contacts.resolved_contacts(use_crm_v2: @account.feature_enabled?('crm_v2'))
            end
    scope.includes(:taggings, :labels)
  end

  def valid_headers(column_names)
    available_columns = Contact.column_names + @custom_attribute_keys + ['labels']
    (column_names.presence || default_columns) & available_columns
  end

  def attach_export_file(csv_data)
    return if csv_data.blank?

    @account.contacts_export.attach(
      io: StringIO.new(csv_data),
      filename: "#{@account.name}_#{@account.id}_contacts.csv",
      content_type: 'text/csv'
    )
  end

  def send_mail
    file_url = account_contact_export_url
    mailer = AdministratorNotifications::AccountNotificationMailer.with(account: @account)
    mailer.contact_export_complete(file_url, @account_user.email)&.deliver_later
  end

  def account_contact_export_url
    Rails.application.routes.url_helpers.rails_blob_url(@account.contacts_export)
  end

  def default_columns
    standard_columns + @custom_attribute_keys
  end

  def standard_columns
    %w[id name email phone_number identifier created_at last_activity_at location city country_code middle_name last_name blocked company_name lead_score lead_source is_lead labels]
  end
end
