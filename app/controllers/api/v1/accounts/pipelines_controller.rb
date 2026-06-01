# frozen_string_literal: true

class Api::V1::Accounts::PipelinesController < Api::V1::Accounts::BaseController
  before_action :fetch_pipeline, only: [:show, :update, :destroy]

  def index
    @pipelines = Current.account.pipelines.includes(:stages)
  end

  def show; end

  def create
    authorize Pipeline
    @pipeline = Current.account.pipelines.new(pipeline_params)
    @pipeline.save!
  end

  def update
    authorize @pipeline
    @pipeline.update!(pipeline_params)
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
    @pipeline = Current.account.pipelines.find(params[:id])
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
