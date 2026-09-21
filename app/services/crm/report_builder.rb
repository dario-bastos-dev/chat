# frozen_string_literal: true

# Metricas do CRM de um unico funil. Todas partem de um escopo ja filtrado por
# permissao, para o relatorio nunca mostrar negocios que o usuario nao pode ver
# no Kanban.
#
# Cada metrica usa a data do evento que ela mede: novos pela criacao, ganhos
# por won_at e perdidos por lost_at. Assim "ganhos no periodo" sao os negocios
# fechados no periodo, e nao os criados nele que por acaso ja fecharam. O que e
# "em aberto" e sempre a situacao atual, independente do periodo.
class Crm::ReportBuilder
  GROUP_BY = { 'day' => :day, 'week' => :week, 'month' => :month, 'year' => :year }.freeze
  DEFAULT_RANGE_DAYS = 30
  TOP_OPEN_DEALS_LIMIT = 5

  def initialize(account:, scope:, params: {})
    @account = account
    @scope = scope
    @params = params
  end

  # Tudo sai de uma chamada so, com os mesmos parametros: secoes buscadas em
  # requisicoes separadas chegavam a mostrar periodos diferentes na mesma tela.
  def overview
    {
      currency: @account.crm_currency,
      summary: summary,
      timeline: timeline,
      openPipeline: open_pipeline,
      agents: agents,
      topOpenDeals: top_open_deals
    }
  end

  def summary
    won_count = won_deals.count
    lost_count = lost_deals.count

    {
      newDeals: new_deals.count,
      wonDeals: won_count,
      wonValue: won_deals.sum(:value).to_f,
      lostDeals: lost_count,
      lostValue: lost_deals.sum(:value).to_f,
      winRate: rate(won_count, won_count + lost_count),
      avgCycleDays: avg_cycle_days,
      openDeals: open_deals.count,
      openValue: open_deals.sum(:value).to_f
    }
  end

  def timeline
    created = new_deals.group_by_period(group_by, :created_at, range: range).count
    won = won_deals.group_by_period(group_by, :won_at, range: range).count
    lost = lost_deals.group_by_period(group_by, :lost_at, range: range).count

    created.keys.map do |date|
      { date: date.to_s, created: created[date] || 0, won: won[date] || 0, lost: lost[date] || 0 }
    end
  end

  # Negocios abertos hoje, por etapa. Etapas de ganho/perda ficam de fora: um
  # negocio nelas nunca esta aberto (Deal#sync_status_with_stage_type).
  def open_pipeline
    counts = open_deals.group(:stage_id).count
    values = open_deals.group(:stage_id).sum(:value)

    stages.where.not(stage_type: %w[done closed]).map do |stage|
      { id: stage.id, name: stage.name, color: stage.color, count: counts[stage.id] || 0, value: (values[stage.id] || 0).to_f }
    end
  end

  # Uma linha por responsavel, incluindo "sem responsavel" (id nil), para a
  # soma da tabela bater com os totais do resumo.
  def agents
    created = new_deals.group(:assignee_id).count
    won = won_deals.group(:assignee_id).count
    lost = lost_deals.group(:assignee_id).count
    won_values = won_deals.group(:assignee_id).sum(:value)
    open = open_deals.group(:assignee_id).count

    ids = (created.keys + won.keys + lost.keys + open.keys).uniq
    users = User.where(id: ids.compact).index_by(&:id)

    ids.map do |id|
      won_count = won[id] || 0
      {
        id: id,
        name: users[id]&.name,
        thumbnail: users[id]&.avatar_url,
        newDeals: created[id] || 0,
        wonDeals: won_count,
        lostDeals: lost[id] || 0,
        wonValue: (won_values[id] || 0).to_f,
        winRate: rate(won_count, won_count + (lost[id] || 0)),
        openDeals: open[id] || 0
      }
    end.sort_by { |row| [-row[:wonValue], -row[:wonDeals], -row[:newDeals], -row[:openDeals]] }
  end

  # So negocios com valor: listar os de valor zero nao aponta prioridade nenhuma.
  def top_open_deals
    open_deals.where('deals.value > 0')
              .includes(:contact, :stage, :assignee)
              .order(value: :desc, id: :desc)
              .limit(TOP_OPEN_DEALS_LIMIT)
              .map do |deal|
      {
        id: deal.id,
        title: deal.title,
        value: deal.value.to_f,
        contactName: deal.contact&.name,
        stageName: deal.stage&.name,
        assigneeName: deal.assignee&.name
      }
    end
  end

  private

  def pipeline_scope
    @pipeline_scope ||= @scope.where(pipeline_id: @params.fetch(:pipeline_id))
  end

  def new_deals
    pipeline_scope.where(created_at: range)
  end

  def won_deals
    pipeline_scope.won_deals.where(won_at: range)
  end

  def lost_deals
    pipeline_scope.lost_deals.where(lost_at: range)
  end

  def open_deals
    pipeline_scope.open_deals
  end

  def stages
    Stage.joins(:pipeline)
         .where(pipelines: { account_id: @account.id }, pipeline_id: @params.fetch(:pipeline_id))
         .ordered
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

  # nil quando nao ha base: "0%" ou "0 dias" sem nenhum negocio fechado e um
  # numero inventado.
  def rate(part, total)
    return if total.zero?

    (part * 100.0 / total).round(1)
  end

  def avg_cycle_days
    durations = won_deals.pluck(:created_at, :won_at).map { |created, won| (won - created) / 1.day }
    return if durations.empty?

    (durations.sum / durations.size).round(2)
  end
end
