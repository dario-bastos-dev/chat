class Deals::StageAutomationJob < ApplicationJob
  queue_as :default

  def perform(event_name, event_data)
    @data = event_data.with_indifferent_access
    
    case event_name
    when 'conversation.status_changed'
      handle_conversation_resolved if @data[:status] == 'resolved'
    when 'webwidget.triggered'
      # Example: Create deal when widget triggered (optional)
    end
  end

  private

  def handle_conversation_resolved
    conversation = Conversation.find_by(id: @data[:id])
    return unless conversation

    # Find linked open deals
    conversation.deals.open_deals.each do |deal|
      # Logic: If conversation is resolved, maybe verify if deal should move?
      # For now, we just add an activity note
      deal.deal_activities.create!(
        account: deal.account,
        user: conversation.assignee, # Who resolved the chat
        activity_type: 'note',
        description: "Linked conversation ##{conversation.display_id} was resolved."
      )
    end
  end

  def handle_message_created
    # Logic to update last_activity_at is handled by listener directly usually,
    # but could be here for complex automation like "Move to Reply Received stage"
  end
end
