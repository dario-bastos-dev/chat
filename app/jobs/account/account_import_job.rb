class Account::AccountImportJob < ApplicationJob
  queue_as :low

  def perform(account_id, email_to)
    @account = Account.find(account_id)
    return unless @account.account_import_file.attached?

    # Baixa e faz parse do arquivo JSON
    json_content = @account.account_import_file.download
    data = JSON.parse(json_content)

    # Executa a importação
    importer = AccountImporter.new(data: data, target_account: @account)
    importer.perform

    # Remove o arquivo temporário de importação do storage
    @account.account_import_file.purge

    # Envia e-mail de sucesso
    mailer = AdministratorNotifications::AccountNotificationMailer.with(account: @account)
    mailer.account_import_complete(@account.id, email_to).deliver_now
  rescue => e
    # Registra o log do erro
    Rails.logger.error "[IMPORT JOB ERROR] Ocorreu uma falha ao importar a conta: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    # Extrai o nome da conta original para o e-mail de falha
    account_name = nil
    if defined?(data) && data.present? && data['account'].present?
      account_name = data['account']['name']
    end
    account_name ||= "Conta temporária"

    # Destrói a conta temporária para não deixar lixo no banco de dados
    if @account.present? && !@account.destroyed?
      @account.destroy
    end

    # Envia e-mail de falha
    mailer = AdministratorNotifications::AccountNotificationMailer.new
    mailer.account_import_failed(account_name, email_to, e.message).deliver_now

    # Re-levanta o erro para o processador de jobs (Sidekiq)
    raise e
  end
end
