# frozen_string_literal: true

class Deals::StageMover
  def initialize(deal:, new_stage:, new_position: nil)
    @deal = deal
    @new_stage = new_stage
    @new_position = new_position
  end

  def perform
    ActiveRecord::Base.transaction do
      validate_stage!
      move_deal
      reorder_siblings if @new_position.present?
      @deal
    end
  end

  private

  def validate_stage!
    return if @new_stage.pipeline_id == @deal.pipeline_id

    raise ArgumentError, 'Stage must belong to the same pipeline'
  end

  def move_deal
    old_stage_id = @deal.stage_id
    
    @deal.stage = @new_stage
    @deal.position = @new_position if @new_position.present?
    @deal.last_activity_at = Time.current
    @deal.save!

    # Create activity log for stage change
    create_stage_change_activity(old_stage_id)
  end

  def reorder_siblings
    # Move other deals down to make room
    @deal.class
         .where(stage_id: @new_stage.id, status: 'open')
         .where('position >= ?', @new_position)
         .where.not(id: @deal.id)
         .update_all('position = position + 1')
  end

  def create_stage_change_activity(old_stage_id)
    old_stage = Stage.find(old_stage_id)
    
    DealActivity.create!(
      deal: @deal,
      account: @deal.account,
      activity_type: 'note',
      description: "Movido de '#{old_stage.name}' para '#{@new_stage.name}'"
    )
  end
end
