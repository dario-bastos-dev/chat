class Deals::AutoAssignmentJob < ApplicationJob
  queue_as :default

  def perform(deal_id)
    deal = Deal.find_by(id: deal_id)
    return unless deal
    return if deal.assignee_id.present?

    # 1. Identify Candidate Agents
    candidates = identify_candidates(deal)
    return if candidates.empty?

    # 2. Select Best Candidate (Least Load Strategy)
    # Orders by number of open deals assigned to the user
    selected_agent = candidates.sort_by { |user| user.deals.where(status: 'open').count }.first

    # 3. Assign
    if selected_agent
      deal.update!(assignee: selected_agent)
      
      # Create activity log
      deal.deal_activities.create!(
        account: deal.account,
        activity_type: 'note',
        description: "Auto-assigned to #{selected_agent.name} based on workload."
      )

      # Dispatch update event
      Rails.configuration.dispatcher.dispatch('deal.updated', deal, { changed_attributes: ['assignee_id'] })
    end
  end

  private

  def identify_candidates(deal)
    # If deal is linked to an inbox, prefer inbox members
    if deal.inbox
      return deal.inbox.members
    end

    # Otherwise, all agents in the account with access to deals
    # (Assuming all agents have access for now, or filter by role/team)
    deal.account.users.where(role: ['agent', 'administrator'])
  end
end
