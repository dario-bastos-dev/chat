# frozen_string_literal: true

class Api::V1::Accounts::StagesController < Api::V1::Accounts::BaseController
  before_action :fetch_pipeline
  before_action :fetch_stage, only: [:show, :update, :destroy]

  def index
    @stages = @pipeline.stages.ordered
  end

  def show; end

  def create
    authorize Stage
    @stage = @pipeline.stages.new(stage_params)
    @stage.save!
  end

  def update
    authorize @stage
    @stage.update!(stage_params)
  end

  def destroy
    authorize @stage
    
    if @stage.deals.exists?
      render_could_not_create_error('Stage has deals associated and cannot be deleted')
    else
      @stage.destroy!
      head :ok
    end
  end

  def reorder
    authorize Stage
    
    params[:stage_ids].each_with_index do |stage_id, index|
      @pipeline.stages.find(stage_id).update!(position: index)
    end
    
    @stages = @pipeline.stages.ordered
    render :index
  end

  private

  def fetch_pipeline
    @pipeline = Current.account.pipelines.find(params[:pipeline_id])
  end

  def fetch_stage
    @stage = @pipeline.stages.find(params[:id])
  end

  def stage_params
    params.require(:stage).permit(:name, :position, :win_probability, :rotting_days)
  end
end
