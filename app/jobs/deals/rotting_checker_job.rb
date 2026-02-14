class Deals::RottingCheckerJob < ApplicationJob
  queue_as :low_priority

  def perform
    # Find all stages that have rotting_days configured
    Stage.where.not(rotting_days: [nil, 0]).find_each do |stage|
      rotting_threshold = stage.rotting_days.days.ago
      
      # Find open deals in this stage that haven't been updated recently
      # Using last_activity_at as the primary indicator, fallback to updated_at
      stage.deals.open_deals.where('last_activity_at < ? OR (last_activity_at IS NULL AND updated_at < ?)', rotting_threshold, rotting_threshold).find_each do |deal|
        # Skip if already marked as rotting to avoid redundant updates/events
        # Assuming custom_attributes stores boolean as true, or check for presence
        next if deal.custom_attributes['is_rotting'] == true
        
        # Mark as rotting
        deal.custom_attributes['is_rotting'] = true
        deal.save!
        
        # Dispatch event for notifications/webhooks
        Rails.configuration.dispatcher.dispatch(
          'deal.rotting', 
          deal, 
          { days_inactive: (Time.current - (deal.last_activity_at || deal.updated_at)).to_i / 1.day }
        )
      end
    end
  end
end
