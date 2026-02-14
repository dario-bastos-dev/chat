class DealListener < BaseListener
  def conversation_created(event)
    conversation = event.data[:conversation]
    contact = conversation.contact
    
    # Auto-link open deals from this contact to the new conversation
    contact.deals.open_deals.each do |deal|
      ConversationDeal.create(conversation: conversation, deal: deal)
    end
  end

  def message_created(event)
    message = event.data[:message]
    conversation = message.conversation
    
    # Update last_activity_at for all linked deals
    conversation.deals.open_deals.each do |deal|
      deal.update(last_activity_at: message.created_at)
      
      # If deal was rotting, remove the flag since there is activity
      if deal.custom_attributes['is_rotting']
        deal.custom_attributes['is_rotting'] = false
        deal.save
      end
    end
  end

  def conversation_resolved(event)
    # Trigger automation job
    Deals::StageAutomationJob.perform_later('conversation.status_changed', event.data)
  end
end
