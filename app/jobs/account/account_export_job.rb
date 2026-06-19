class Account::AccountExportJob < ApplicationJob
  queue_as :low

  def perform(account_id, email_to)
    @account = Account.find(account_id)
    Current.account = @account

    exporter = AccountExporter.new(account: @account)
    data = exporter.perform

    json_data = JSON.pretty_generate(data)

    @account.account_export.attach(
      io: StringIO.new(json_data),
      filename: "chatwoot_export_account_#{@account.id}_#{Time.now.to_i}.json",
      content_type: 'application/json'
    )

    send_mail(email_to)
  end

  private

  def send_mail(email_to)
    file_url = Rails.application.routes.url_helpers.rails_blob_url(@account.account_export)
    mailer = AdministratorNotifications::AccountNotificationMailer.with(account: @account)
    mailer.account_export_complete(file_url, email_to)&.deliver_now
  end
end
