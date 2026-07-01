class SuperAdmin::AccountsController < SuperAdmin::ApplicationController
  # Overwrite any of the RESTful controller actions to implement custom behavior
  # For example, you may want to send an email after a foo is updated.
  #
  # def update
  #   super
  #   send_foo_updated_email(requested_resource)
  # end

  # Override this method to specify custom lookup behavior.
  # This will be used to set the resource for the `show`, `edit`, and `update`
  # actions.
  #
  # def find_resource(param)
  #   Foo.find_by!(slug: param)
  # end

  # The result of this lookup will be available as `requested_resource`

  # Override this if you have certain roles that require a subset
  # this will be used to set the records shown on the `index` action.
  #
  # def scoped_resource
  #   if current_user.super_admin?
  #     resource_class
  #   else
  #     resource_class.with_less_stuff
  #   end
  # end

  # Override `resource_params` if you want to transform the submitted
  # data before it's persisted. For example, the following would turn all
  # empty values into nil values. It uses other APIs such as `resource_class`
  # and `dashboard`:
  #
  def resource_params
    permitted_params = super
    permitted_params[:limits] = permitted_params[:limits].to_h.compact if permitted_params.key?(:limits)
    permitted_params[:captain_models] = permitted_params[:captain_models].to_h.compact_blank.presence if permitted_params.key?(:captain_models)
    permitted_params[:selected_feature_flags] = params[:enabled_features].keys.map(&:to_sym) if params[:enabled_features].present?
    permitted_params
  end

  # See https://administrate-prototype.herokuapp.com/customizing_controller_actions
  # for more information

  def seed
    Internal::SeedAccountJob.perform_later(requested_resource)
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Account seeding triggered')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def reset_cache
    requested_resource.reset_cache_keys
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Cache keys cleared')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def destroy
    account = Account.find(params[:id])

    DeleteObjectJob.perform_later(account) if account.present?
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_back(fallback_location: [namespace, requested_resource], notice: 'Account deletion is in progress.')
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def export
    account = Account.find(params[:id])
    Account::AccountExportJob.perform_later(account.id, current_user.email)
    
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_to super_admin_account_path(account), notice: "O processo de exportação foi iniciado em segundo plano. Você receberá um e-mail em #{current_user.email} com o link de download assim que for concluído."
    # rubocop:enable Rails/I18nLocaleTexts
  end

  def import
    if params[:import_file].present?
      file = params[:import_file]
      
      # Lê o JSON rapidamente para extrair o nome original da conta
      json_data = JSON.parse(file.read)
      file.rewind # Volta o ponteiro do arquivo para o início para podermos anexá-lo
      
      account_name = json_data.dig('account', 'name') || "Importada"

      # Cria a conta temporária com nome descritivo
      new_account = Account.create!(name: "#{account_name} (Importando...)")

      # Anexa o arquivo JSON físico à conta temporária
      new_account.account_import_file.attach(
        io: file,
        filename: file.original_filename,
        content_type: 'application/json'
      )

      # Dispara o job assíncrono passando o ID da conta temporária e o e-mail do super admin
      Account::AccountImportJob.perform_later(new_account.id, current_user.email)

      # rubocop:disable Rails/I18nLocaleTexts
      redirect_to super_admin_account_path(new_account), notice: "A importação da conta foi iniciada em segundo plano. Você receberá um e-mail em #{current_user.email} informando se o processo foi concluído com sucesso."
      # rubocop:enable Rails/I18nLocaleTexts
    else
      # rubocop:disable Rails/I18nLocaleTexts
      redirect_to new_super_admin_account_path, alert: "Por favor, selecione um arquivo JSON."
      # rubocop:enable Rails/I18nLocaleTexts
    end
  rescue => e
    # rubocop:disable Rails/I18nLocaleTexts
    redirect_to new_super_admin_account_path, alert: "Falha ao analisar o arquivo JSON: #{e.message}"
    # rubocop:enable Rails/I18nLocaleTexts
  end
end

SuperAdmin::AccountsController.prepend_mod_with('SuperAdmin::AccountsController')
