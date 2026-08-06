# frozen_string_literal: true

# Monta negocios a partir das linhas de um CSV, reaproveitando o contato quando
# ele ja existe. Substitui o import que rodava no navegador, que criava um
# contato novo por linha e, ao falhar, vinculava o negocio ao contato de outro
# negocio da tela — ou ao id 1.
class DataImport::DealManager
  REQUIRED_COLUMN = 'title'

  def initialize(account, pipeline: nil)
    @account = account
    @pipeline = pipeline || account.pipelines.find_by(is_default: true) || account.pipelines.first
    @contact_manager = DataImport::ContactManager.new(account)
    @stages_by_name = @pipeline&.stages&.index_by { |stage| stage.name.to_s.downcase } || {}
  end

  def usable?
    @pipeline.present? && default_stage.present?
  end

  # Devolve um Deal nao salvo. Erros de validacao ficam no proprio objeto, para
  # o job separar aceitos de rejeitados como ja faz com contatos.
  def build_deal(params)
    deal = @account.deals.new(
      pipeline: @pipeline,
      stage: resolve_stage(params[:stage]),
      title: params[REQUIRED_COLUMN].presence || params[:title],
      value: parse_value(params[:value]),
      assignee: resolve_assignee(params[:assignee_email])
    )
    deal.contact = resolve_contact(params)
    deal.custom_attributes = extra_columns(params)
    deal
  end

  private

  def default_stage
    @default_stage ||= @pipeline&.stages&.min_by(&:position)
  end

  def resolve_stage(name)
    return default_stage if name.blank?

    @stages_by_name[name.to_s.downcase] || default_stage
  end

  # Sem contato nao existe negocio valido. Deixamos o contact nil para a
  # validacao do model rejeitar a linha, em vez de inventar um vinculo.
  def resolve_contact(params)
    return nil if params[:contact_email].blank? && params[:contact_phone].blank? && params[:contact_name].blank?

    contact = @contact_manager.build_contact(
      { name: params[:contact_name], email: params[:contact_email], phone_number: params[:contact_phone] }.compact
    )
    contact.save if contact.new_record? && contact.valid?
    contact.persisted? ? contact : nil
  end

  def resolve_assignee(email)
    return nil if email.blank?

    @account.users.find_by(email: email.to_s.strip.downcase)
  end

  def parse_value(raw)
    return 0 if raw.blank?

    # Aceita "1.234,56" e "1234.56"
    normalized = raw.to_s.strip.gsub(/[^\d,.-]/, '')
    normalized = normalized.tr('.', '').tr(',', '.') if normalized.count(',') == 1 && normalized.rindex(',').to_i > normalized.rindex('.').to_i
    value = BigDecimal(normalized)
    value.negative? ? 0 : value
  rescue ArgumentError, TypeError
    0
  end

  KNOWN_COLUMNS = %w[title value stage contact_name contact_email contact_phone assignee_email].freeze

  def extra_columns(params)
    params.to_h.except(*KNOWN_COLUMNS).compact_blank
  end
end
