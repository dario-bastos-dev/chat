class DealListener < BaseListener
  def conversation_created(event)
    conversation = event.data[:conversation]
    contact = conversation.contact
    
    # Auto-link open deals from this contact to the new conversation
    contact.deals.open_deals.each do |deal|
      ConversationDeal.find_or_create_by(conversation: conversation, deal: deal)
    end
  end

  # Roda a cada mensagem recebida, entao precisa ser barato. Antes era um UPDATE
  # por negocio aberto, e cada um disparava os callbacks e o evento deal.updated
  # em cascata. Um unico update_all resolve os dois campos de uma vez.
  def message_created(event)
    message = event.data[:message]
    deals = message.conversation.deals.open_deals

    deals.update_all(
      last_activity_at: message.created_at,
      custom_attributes: Arel.sql("custom_attributes || '{\"is_rotting\": false}'::jsonb")
    )
  end

  def conversation_resolved(event)
    # Trigger automation job to potentially move linked deals
    Deals::StageAutomationJob.perform_later('conversation.status_changed', event.data)
  end

  # CRM: Auto-assign deal to an agent via round-robin when created without assignee
  def deal_created(event)
    deal = event.data[:deal]
    return if deal.assignee_id.present?

    Deals::AutoAssignmentJob.perform_later(deal.id)
  end

  # CRM: Trigger stage automation when deal moves between stages
  def deal_stage_changed(event)
    deal = event.data[:deal]
    from_stage_id = event.data[:from_stage_id]
    to_stage_id = event.data[:to_stage_id]

    Deals::StageAutomationJob.perform_later('deal.stage_changed', {
      deal_id: deal.id,
      from_stage_id: from_stage_id,
      to_stage_id: to_stage_id,
      account_id: deal.account_id
    })
  end

  # CRM: Create activity record when deal is won
  def deal_won(event)
    deal = event.data[:deal]
    create_status_activity(deal, 'won', "Negócio marcado como ganho.")
  end

  # CRM: Create activity record when deal is lost
  def deal_lost(event)
    deal = event.data[:deal]
    create_status_activity(deal, 'lost', "Negócio marcado como perdido. Motivo: #{deal.lost_reason}")
  end

  # CRM: When contact is updated, sync lead_score to open deals
  def contact_updated(event)
    contact = event.data[:contact]
    changed = event.data[:changed_attributes] || {}
    
    return unless changed.key?('lead_score') || changed.key?('is_lead')
    
    contact.deals.open_deals.each do |deal|
      deal.custom_attributes['contact_lead_score'] = contact.lead_score
      deal.custom_attributes['contact_is_lead'] = contact.is_lead
      deal.save
    end
  end

  private

  def create_status_activity(deal, status, description)
    deal.deal_activities.create(
      activity_type: 'note',
      description: description,
      account: deal.account,
      completed_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.error("DealListener: Failed to create #{status} activity for deal #{deal.id}: #{e.message}")
  end
end
