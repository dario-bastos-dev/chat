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

    # Envia e-mail de sucesso com tratamento isolado para falhas de SMTP
    begin
      mailer = AdministratorNotifications::AccountNotificationMailer.with(account: @account)
      mailer.account_import_complete(@account.id, email_to).deliver_now
    rescue => mail_err
      Rails.logger.error "[IMPORT JOB] Importação concluída, mas falhou ao enviar email de sucesso: #{mail_err.class} - #{mail_err.message}"
    end
  rescue => e
    # Registra o log do erro original
    Rails.logger.error "[IMPORT JOB ERROR] Ocorreu uma falha ao importar a conta: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    # Extrai o nome da conta original para o e-mail de falha
    account_name = nil
    if defined?(data) && data.present? && data['account'].present?
      account_name = data['account']['name']
    end
    account_name ||= "Conta temporária"

    # Destrói a conta temporária apenas se a falha ocorreu antes da conclusão da importação
    if @account.present? && !@account.destroyed?
      begin
        @account.destroy
      rescue => destroy_err
        Rails.logger.error "[IMPORT JOB] Erro ao limpar conta temporária: #{destroy_err.message}"
      end
    end

    # Envia e-mail de falha com tratamento isolado para falhas de SMTP
    begin
      AdministratorNotifications::AccountNotificationMailer.account_import_failed(account_name, email_to, e.message).deliver_now
    rescue => mail_err
      Rails.logger.error "[IMPORT JOB] Importação falhou e também ocorreu erro ao enviar o email de aviso: #{mail_err.class} - #{mail_err.message}"
    end
  end
end
