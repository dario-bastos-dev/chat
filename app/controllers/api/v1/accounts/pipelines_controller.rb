# frozen_string_literal: true

class Api::V1::Accounts::PipelinesController < Api::V1::Accounts::BaseController
  before_action :fetch_pipeline, only: [:show, :update, :destroy]

  def index
    ::Pipelines::CreateDefaultService.new(Current.account).perform if Current.account.pipelines.count.zero?
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
    
    if @pipeline.deals.exists?
      render_could_not_create_error('Pipeline has deals associated and cannot be deleted')
    else
      @pipeline.destroy!
      head :ok
    end
  end

  private

  def fetch_pipeline
    @pipeline = Current.account.pipelines.find(params[:id])
  end

  def pipeline_params
    params.require(:pipeline).permit(:name, :is_default)
  end
end
