# frozen_string_literal: true

class Deals::Creator
  def initialize(account:, params:, user: nil)
    @account = account
    @params = params
    @user = user
  end

  def perform
    ActiveRecord::Base.transaction do
      create_deal
      link_conversation if @params[:conversation_id].present?
      @deal
    end
  end

  private

  def create_deal
    @deal = @account.deals.new(deal_params)
    @deal.assignee = @user if @deal.assignee_id.nil? && @user.present?
    @deal.last_activity_at = Time.current
    @deal.save!
  end

  def link_conversation
    conversation = @account.conversations.find(@params[:conversation_id])
    ConversationDeal.create!(
      conversation: conversation,
      deal: @deal,
      is_primary: true
    )
  end

  def deal_params
    @params.slice(
      :title, :stage_id, :pipeline_id,
      :contact_id, :inbox_id, :assignee_id,
      :position, :custom_attributes
    )
  end
end
