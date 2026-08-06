# frozen_string_literal: true

class Api::V1::Accounts::Crm::ReportsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def summary
    render json: builder.summary
  end

  def funnel
    render json: builder.funnel
  end

  def deals_over_time
    render json: builder.deals_over_time
  end

  def won_lost
    render json: builder.won_lost
  end

  def agent_performance
    render json: builder.agent_performance
  end

  def cycle_time
    render json: builder.cycle_time
  end

  def top_deals
    render json: builder.top_deals
  end

  def download
    send_data to_csv, filename: "crm-report-#{Date.current}.csv", type: 'text/csv'
  end

  private

  def check_authorization
    authorize :report, :view?
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
    params.permit(:from, :to, :pipeline_id, :group_by, :limit, :status, :report_type).to_h.symbolize_keys
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << ['Etapa', 'Negócios', 'Valor']
      builder.funnel.each { |row| csv << [row[:name], row[:count], row[:value]] }

      csv << []
      csv << ['Agente', 'Negócios', 'Ganhos', 'Valor', 'Taxa de ganho (%)']
      builder.agent_performance.each do |row|
        csv << [row[:name], row[:totalDeals], row[:wonDeals], row[:totalValue], row[:winRate]]
      end
    end
  end
end
