# frozen_string_literal: true

class Api::V1::Accounts::PipelinesController < Api::V1::Accounts::BaseController
  DEFAULT_DEALS_PER_STAGE = 20
  MAX_DEALS_PER_STAGE = 100

  before_action :fetch_pipeline, only: [:show, :update, :destroy, :board]

  def index
    @pipelines = policy_scope(Pipeline).includes(:stages)
    @deal_counts = open_deal_counts_by_stage
  end

  def show
    @deal_counts = open_deal_counts_by_stage(@pipeline.id)
  end

  # Payload inicial do Kanban: as primeiras N oportunidades de cada etapa mais o
  # total real da coluna. O total precisa vir do banco, senao o contador reflete
  # apenas o que coube na pagina.
  def board
    scope = Deals::Finder.new(scope: policy_scope(Deal), params: board_filters).perform

    @stages = @pipeline.stages.ordered
    @total_counts = scope.group(:stage_id).count
    @total_values = scope.group(:stage_id).sum(:value)
    @weighted_forecast = weighted_forecast_for(scope)
    @currency = Current.account.crm_currency
    @deals_by_stage = @stages.index_with do |stage|
      scope.where(stage_id: stage.id)
           .includes(:contact, :assignee, :stage, :pipeline)
           .ordered_by_position
           .limit(deals_per_stage)
    end
  end

  def create
    authorize Pipeline
    @pipeline = Current.account.pipelines.new(pipeline_params)
    @pipeline.save!
  end

  def update
    authorize @pipeline
    ActiveRecord::Base.transaction do
      if pipeline_params[:stages_attributes].present?
        # Incrementa temporariamente as posições no banco para evitar colisões de chave única
        @pipeline.stages.update_all('position = position + 1000')
      end

      @pipeline.update!(pipeline_params)

      # Normaliza sequencialmente as posições das etapas ativas de 1 em diante
      @pipeline.stages.reload.order(position: :asc).each_with_index do |stage, index|
        stage.update_columns(position: index + 1)
      end
    end
  end

  def destroy
    authorize @pipeline
    
    if @pipeline.destroy
      head :ok
    else
      render_could_not_create_error(@pipeline.errors.full_messages.join(', '))
    end
  end

  private

  def fetch_pipeline
    @pipeline = policy_scope(Pipeline).find(params[:id])
  end

  # Uma unica query agregada no lugar de um COUNT por etapa e por funil, que
  # antes vinham dos metodos deals_count/total_deals_count dos models.
  def open_deal_counts_by_stage(pipeline_id = nil)
    scope = policy_scope(Deal).where(status: 'open')
    scope = scope.where(pipeline_id: pipeline_id) if pipeline_id
    scope.group(:stage_id).count
  end

  # Forecast ponderado: soma de valor x probabilidade da etapa, apenas sobre
  # negocios abertos. E a metrica que o `win_probability`, ate agora sem uso
  # pratico, finalmente viabiliza.
  def weighted_forecast_for(scope)
    scope.where(status: 'open')
         .joins(:stage)
         .sum('deals.value * stages.win_probability / 100.0')
  end

  def deals_per_stage
    [(params[:per_stage].presence || DEFAULT_DEALS_PER_STAGE).to_i, MAX_DEALS_PER_STAGE].min
  end

  def board_filters
    params.permit(:status, :assignee_id, :q, :label, :custom_field_key, :custom_field_value,
                  :min_value, :max_value)
          .to_h.symbolize_keys
          .merge(pipeline_id: @pipeline.id)
  end

  def pipeline_params
    params.require(:pipeline).permit(
      :name,
      :is_default,
      :visibility,
      lost_reasons: [],
      allowed_team_ids: [],
      stages_attributes: [:id, :name, :position, :win_probability, :rotting_days, :color, :stage_type, :_destroy]
    )
  end
end
