class Deals::StageAutomationJob < ApplicationJob
  queue_as :default

  def perform(event_name, event_data)
    @data = event_data.with_indifferent_access
    
    case event_name
    when 'conversation.status_changed'
      handle_conversation_resolved if @data[:status] == 'resolved'
    when 'deal.stage_changed'
      handle_deal_stage_changed
    when 'conversation.tagged'
      handle_conversation_tagged
    end
  end

  private

  def handle_conversation_resolved
    conversation = Conversation.find_by(id: @data[:id])
    return unless conversation

    # Find linked open deals
    conversation.deals.open_deals.each do |deal|
      deal.deal_activities.create(
        account: deal.account,
        user: conversation.assignee,
        activity_type: 'note',
        description: "Linked conversation ##{conversation.display_id} was resolved."
      )
    end
  end

  def handle_deal_stage_changed
    deal = Deal.find_by(id: @data[:deal_id])
    return unless deal

    to_stage = Stage.find_by(id: @data[:to_stage_id])
    return unless to_stage

    # Auto-win: if the deal moves to a stage with 100% win probability
    if to_stage.win_probability == 100 && deal.status == 'open'
      deal.mark_as_won!
      return
    end

    # Create activity log for the stage move
    from_stage = Stage.find_by(id: @data[:from_stage_id])
    deal.deal_activities.create(
      account: deal.account,
      activity_type: 'note',
      description: "Deal moved from '#{from_stage&.name || 'Unknown'}' to '#{to_stage.name}'."
    )
  end

  def handle_conversation_tagged
    conversation = Conversation.find_by(id: @data[:conversation_id])
    return unless conversation

    tag = @data[:tag]
    return unless tag.present?

    # Example automation: if conversation is tagged with "sale" or "venda",
    # auto-create a deal if the contact doesn't have one open
    return unless %w[sale venda negocio deal].include?(tag.downcase)
    return if conversation.contact.deals.open_deals.any?

    account = conversation.account
    default_pipeline = account.pipelines.find_by(is_default: true) || account.pipelines.first
    return unless default_pipeline

    first_stage = default_pipeline.stages.order(position: :asc).first
    return unless first_stage

    deal = Deal.create(
      account: account,
      pipeline: default_pipeline,
      stage: first_stage,
      contact: conversation.contact,
      inbox: conversation.inbox,
      assignee: conversation.assignee,
      title: "#{conversation.contact.name} - ##{conversation.display_id}",
      last_activity_at: Time.current
    )

    # Link the conversation to the deal
    ConversationDeal.find_or_create_by(conversation: conversation, deal: deal) if deal.persisted?
  end
end
