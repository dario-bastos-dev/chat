# frozen_string_literal: true

# Metricas do CRM. Todas partem de um escopo ja filtrado por permissao, para o
# relatorio nunca mostrar negocios que o usuario nao pode ver no Kanban.
#
# O periodo filtra pela data de criacao do negocio, exceto onde indicado.
class Crm::ReportBuilder
  GROUP_BY = { 'day' => :day, 'week' => :week, 'month' => :month }.freeze
  DEFAULT_RANGE_DAYS = 30
  TOP_DEALS_LIMIT = 10
  MAX_TOP_DEALS = 50

  def initialize(account:, scope:, params: {})
    @account = account
    @scope = scope
    @params = params
  end

  def summary
    won = period_scope.won_deals
    lost = period_scope.lost_deals
    closed_count = won.count + lost.count

    {
      totalDeals: period_scope.count,
      totalValue: period_scope.sum(:value).to_f,
      wonDeals: won.count,
      lostDeals: lost.count,
      winRate: closed_count.zero? ? 0 : (won.count * 100.0 / closed_count).round(1),
      avgCycleTime: avg_cycle_time_in_days,
      weightedForecast: weighted_forecast,
      currency: @account.crm_currency
    }
  end

  # Um item por etapa do funil, na ordem das etapas.
  def funnel
    counts = period_scope.group(:stage_id).count
    values = period_scope.group(:stage_id).sum(:value)

    stages.map do |stage|
      {
        id: stage.id,
        name: stage.name,
        count: counts[stage.id] || 0,
        value: (values[stage.id] || 0).to_f
      }
    end
  end

  # Criados por data de criacao; ganhos e perdidos pelas datas de fechamento,
  # que e o que faz a serie temporal ser lida corretamente.
  def deals_over_time
    created = period_scope.group_by_period(group_by, :created_at, range: range).count
    won = won_lost_series(:won_at, 'won')
    lost = won_lost_series(:lost_at, 'lost')

    created.keys.map do |date|
      {
        date: date.to_s,
        created: created[date] || 0,
        won: won[date] || 0,
        lost: lost[date] || 0
      }
    end
  end

  def won_lost
    {
      won: period_scope.won_deals.count,
      lost: period_scope.lost_deals.count,
      wonValue: period_scope.won_deals.sum(:value).to_f,
      lostValue: period_scope.lost_deals.sum(:value).to_f,
      lostReasons: period_scope.lost_deals.group(:lost_reason).count
    }
  end

  def agent_performance
    totals = period_scope.where.not(assignee_id: nil).group(:assignee_id).count
    won = period_scope.won_deals.where.not(assignee_id: nil).group(:assignee_id).count
    values = period_scope.where.not(assignee_id: nil).group(:assignee_id).sum(:value)

    User.where(id: totals.keys).map do |user|
      total = totals[user.id] || 0
      won_count = won[user.id] || 0
      {
        id: user.id,
        name: user.name,
        thumbnail: user.avatar_url,
        totalDeals: total,
        wonDeals: won_count,
        totalValue: (values[user.id] || 0).to_f,
        winRate: total.zero? ? 0 : (won_count * 100.0 / total).round(1)
      }
    end.sort_by { |agent| -agent[:totalValue] }
  end

  def cycle_time
    closed = period_scope.won_deals.where.not(won_at: nil)
    durations = closed.pluck(:created_at, :won_at).map { |created, closed_at| (closed_at - created) / 1.day }

    {
      average: durations.any? ? (durations.sum / durations.size).round(1) : 0,
      median: median(durations),
      sampleSize: durations.size
    }
  end

  def top_deals
    limit = [(@params[:limit].presence || TOP_DEALS_LIMIT).to_i, MAX_TOP_DEALS].min
    relation = period_scope
    relation = relation.where(status: @params[:status]) if @params[:status].present?

    relation.includes(:contact, :stage, :assignee)
            .order(value: :desc, id: :desc)
            .limit(limit)
            .map do |deal|
      {
        id: deal.id,
        title: deal.title,
        value: deal.value.to_f,
        status: deal.status,
        contact: { name: deal.contact&.name },
        stage: { name: deal.stage&.name },
        assignee: { name: deal.assignee&.name }
      }
    end
  end

  private

  def period_scope
    @period_scope ||= begin
      relation = @scope.where(created_at: range)
      relation = relation.where(pipeline_id: @params[:pipeline_id]) if @params[:pipeline_id].present?
      relation
    end
  end

  def stages
    scope = Stage.joins(:pipeline).where(pipelines: { account_id: @account.id })
    scope = scope.where(pipeline_id: @params[:pipeline_id]) if @params[:pipeline_id].present?
    scope.ordered
  end

  def range
    @range ||= begin
      to = @params[:to].present? ? Time.zone.at(@params[:to].to_i) : Time.current
      from = @params[:from].present? ? Time.zone.at(@params[:from].to_i) : to - DEFAULT_RANGE_DAYS.days
      from..to
    end
  end

  def group_by
    GROUP_BY[@params[:group_by].to_s] || :day
  end

  def won_lost_series(column, status)
    @scope.where(status: status, column => range)
          .then { |rel| @params[:pipeline_id].present? ? rel.where(pipeline_id: @params[:pipeline_id]) : rel }
          .group_by_period(group_by, column, range: range).count
  end

  def avg_cycle_time_in_days
    durations = period_scope.won_deals.where.not(won_at: nil)
                            .pluck(:created_at, :won_at)
                            .map { |created, closed| (closed - created) / 1.day }
    return 0 if durations.empty?

    (durations.sum / durations.size).round(1)
  end

  def weighted_forecast
    period_scope.where(status: 'open').joins(:stage)
                .sum('deals.value * stages.win_probability / 100.0').to_f
  end

  def median(values)
    return 0 if values.empty?

    sorted = values.sort
    mid = sorted.size / 2
    (sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0).round(1)
  end
end
