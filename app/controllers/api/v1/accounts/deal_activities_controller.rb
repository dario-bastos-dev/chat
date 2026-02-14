# frozen_string_literal: true

class Api::V1::Accounts::DealActivitiesController < Api::V1::Accounts::BaseController
  before_action :fetch_deal
  before_action :fetch_activity, only: [:show, :update, :destroy, :complete]

  def index
    @activities = @deal.deal_activities
                       .includes(:user)
                       .ordered_by_due_date
  end

  def show; end

  def create
    @activity = @deal.deal_activities.new(activity_params)
    @activity.user = current_user
    @activity.account = Current.account
    @activity.save!
  end

  def update
    authorize @activity
    @activity.update!(activity_params)
  end

  def destroy
    authorize @activity
    @activity.destroy!
    head :ok
  end

  def complete
    authorize @activity
    @activity.mark_as_completed!
    render :show
  end

  private

  def fetch_deal
    @deal = Current.account.deals.find(params[:deal_id])
  end

  def fetch_activity
    @activity = @deal.deal_activities.find(params[:id])
  end

  def activity_params
    params.require(:deal_activity).permit(:activity_type, :description, :due_date)
  end
end
