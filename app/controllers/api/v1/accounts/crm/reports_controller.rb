# frozen_string_literal: true

class Api::V1::Accounts::Crm::ReportsController < Api::V1::Accounts::BaseController
  CSV_SUMMARY_ROWS = {
    'Novos negócios' => :newDeals,
    'Ganhos' => :wonDeals,
    'Valor ganho' => :wonValue,
    'Perdidos' => :lostDeals,
    'Valor perdido' => :lostValue,
    'Taxa de ganho (%)' => :winRate,
    'Ciclo médio até o ganho (dias)' => :avgCycleDays,
    'Em aberto agora' => :openDeals,
    'Valor em aberto' => :openValue
  }.freeze
  CSV_AGENT_COLUMNS = %i[newDeals wonDeals lostDeals winRate wonValue openDeals].freeze

  before_action :check_authorization
  before_action :ensure_pipeline

  def overview
    render json: builder.overview
  end

  def download
    send_data to_csv, filename: "crm-report-#{Date.current}.csv", type: 'text/csv'
  end

  private

  def check_authorization
    authorize :report, :view?
  end

  # O relatorio e sempre de um unico funil. Agregar varios mistura etapas de
  # funis diferentes e torna ciclo medio e forecast sem sentido, entao a
  # ausencia do parametro e erro, nao um "todos".
  def ensure_pipeline
    return if params[:pipeline_id].present?

    render_could_not_create_error(I18n.t('errors.crm.reports.pipeline_required'))
  end

  # O escopo passa pela policy de negocios: o relatorio nunca soma negocios que
  # o usuario nao enxerga no Kanban.
  def builder
    @builder ||= Crm::ReportBuilder.new(
      account: Current.account,
      scope: policy_scope(Deal),
      params: report_params
    )
  end

  def report_params
    params.permit(:from, :to, :pipeline_id, :group_by).to_h.symbolize_keys
  end

  def to_csv
    report = builder.overview

    CSV.generate do |csv|
      csv << %w[Indicador Valor]
      CSV_SUMMARY_ROWS.each { |label, key| csv << [label, report[:summary][key]] }

      csv << []
      csv << ['Etapa', 'Negócios em aberto', 'Valor']
      report[:openPipeline].each { |row| csv << [row[:name], row[:count], row[:value]] }

      csv << []
      csv << ['Responsável', 'Novos', 'Ganhos', 'Perdidos', 'Taxa de ganho (%)', 'Valor ganho', 'Em aberto']
      report[:agents].each { |row| csv << [row[:name] || 'Sem responsável', *row.values_at(*CSV_AGENT_COLUMNS)] }
    end
  end
end
