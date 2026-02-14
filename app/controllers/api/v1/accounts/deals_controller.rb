# frozen_string_literal: true

class Api::V1::Accounts::DealsController < Api::V1::Accounts::BaseController
  before_action :fetch_deal, only: [:show, :update, :destroy, :move, :assign, :win, :lose]

  def index
    @deals = policy_scope(Deal)
             .includes(:contact, :assignee, :stage, :pipeline)
             .where(filter_params)
             .ordered_by_position
             .page(params[:page])
             .per(50)
  end

  def show; end

  def create
    @deal = Current.account.deals.new(deal_params)
    @deal.assignee = current_user if @deal.assignee_id.nil?
    @deal.save!
    link_conversation if params[:conversation_id].present?
  end

  def update
    authorize @deal
    @deal.update!(deal_params)
  end

  def destroy
    authorize @deal
    @deal.destroy!
    head :ok
  end

  def move
    authorize @deal
    
    new_stage = Current.account.pipelines
                       .find(@deal.pipeline_id)
                       .stages
                       .find(params[:stage_id])
    
    @deal.move_to_stage!(new_stage, params[:position])
    render :show
  end

  def assign
    authorize @deal
    
    @deal.update!(assignee_id: params[:assignee_id])
    render :show
  end

  def win
    authorize @deal
    @deal.mark_as_won!
    render :show
  end

  def lose
    authorize @deal
    
    if params[:lost_reason].blank?
      render_could_not_create_error('Lost reason is required')
    else
      @deal.mark_as_lost!(params[:lost_reason])
      render :show
    end
  end

  private

  def fetch_deal
    @deal = Current.account.deals.find(params[:id])
  end

  def filter_params
    filters = {}
    filters[:pipeline_id] = params[:pipeline_id] if params[:pipeline_id].present?
    filters[:stage_id] = params[:stage_id] if params[:stage_id].present?
    filters[:status] = params[:status] if params[:status].present?
    filters[:assignee_id] = params[:assignee_id] if params[:assignee_id].present?
    filters[:contact_id] = params[:contact_id] if params[:contact_id].present?
    filters
  end

  def deal_params
    params.require(:deal).permit(
      :title, :value, :currency, :stage_id, :contact_id, :inbox_id,
      :assignee_id, :expected_close_date, :position,
      custom_attributes: {}
    )
  end

  def link_conversation
    conversation = Current.account.conversations.find(params[:conversation_id])
    ConversationDeal.create!(conversation: conversation, deal: @deal, is_primary: true)
  end
end
