class Deals::RottingCheckerJob < ApplicationJob
  queue_as :low_priority

  def perform
    # Find all stages that have rotting_days configured
    Stage.where.not(rotting_days: [nil, 0]).find_each do |stage|
      rotting_threshold = stage.rotting_days.days.ago
      
      # Find open deals in this stage that haven't been updated recently
      stage.deals.open_deals
           .where('last_activity_at < ? OR (last_activity_at IS NULL AND updated_at < ?)', rotting_threshold, rotting_threshold)
           .find_each do |deal|
        deal.mark_as_rotting!
      rescue StandardError => e
        Rails.logger.error("RottingCheckerJob: Failed to mark deal #{deal.id} as rotting: #{e.message}")
      end
    end
  end
end
