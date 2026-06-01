# frozen_string_literal: true

class Deals::Updater
  def initialize(deal:, params:)
    @deal = deal
    @params = params
  end

  def perform
    ActiveRecord::Base.transaction do
      update_deal
      @deal
    end
  end

  private

  def update_deal
    @deal.assign_attributes(deal_params)
    @deal.last_activity_at = Time.current if significant_change?
    @deal.save!
  end

  def significant_change?
    @deal.stage_id_changed? || @deal.status_changed? || @deal.assignee_id_changed?
  end

  def deal_params
    @params.slice(
      :title, :stage_id,
      :assignee_id, :position, :custom_attributes
    )
  end
end
