# frozen_string_literal: true

class Api::V1::Accounts::DealsController < Api::V1::Accounts::BaseController
  before_action :fetch_deal, only: [:show, :update, :destroy, :move, :assign, :win, :lose]

  def index
    @deals = Deals::Finder.new(scope: policy_scope(Deal), params: filter_params).perform
                          .includes(:contact, :assignee, :stage, :pipeline)
                          .ordered_by_position
                          .page(params[:page])
                          .per(per_page)
  end

  def show
    authorize @deal
  end

  def create
    authorize Deal
    @deal = Current.account.deals.new(deal_params.except(:labels))
    @deal.stage = visible_stage!
    @deal.assignee = current_user if @deal.assignee_id.nil?
    ActiveRecord::Base.transaction do
      @deal.save!
      if params[:deal].key?(:labels)
        @deal.update_labels(params[:deal][:labels])
      end
    end
    link_conversation if params[:conversation_id].present?
  end

  def update
    authorize @deal
    ActiveRecord::Base.transaction do
      if params[:deal].key?(:labels)
        @deal.update_labels(params[:deal][:labels])
      end
      @deal.update!(deal_params.except(:labels))
    end
  end

  def destroy
    authorize @deal
    @deal.destroy!
    head :ok
  end

  def move
    authorize @deal

    new_stage = policy_scope(Pipeline).find(@deal.pipeline_id).stages.find(params[:stage_id])

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

  # Guards against creating a deal inside a pipeline the user cannot see.
  def visible_stage!
    Stage.joins(:pipeline).merge(policy_scope(Pipeline)).find(deal_params[:stage_id])
  end

  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100

  def per_page
    [(params[:per_page].presence || DEFAULT_PER_PAGE).to_i, MAX_PER_PAGE].min
  end

  def filter_params
    params.permit(:pipeline_id, :stage_id, :status, :assignee_id, :contact_id, :inbox_id,
                  :q, :label, :custom_field_key, :custom_field_value, :min_value, :max_value)
          .to_h.symbolize_keys
  end

  def deal_params
    params.require(:deal).permit(
      :title, :value, :stage_id, :contact_id, :inbox_id,
      :assignee_id, :position,
      custom_attributes: {},
      labels: []
    )
  end

  def link_conversation
    conversation = Current.account.conversations.find(params[:conversation_id])
    ConversationDeal.create!(conversation: conversation, deal: @deal, is_primary: true)
  end
end
