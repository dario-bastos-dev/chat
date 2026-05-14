class Deals::AutoAssignmentJob < ApplicationJob
  include Events::Types

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
    selected_agent = candidates.min_by { |user| Deal.where(assignee_id: user.id, status: 'open').count }

    # 3. Assign
    return unless selected_agent

    deal.update!(assignee: selected_agent)

    # Create activity log
    deal.deal_activities.create!(
      account: deal.account,
      activity_type: 'note',
      description: "Auto-assigned to #{selected_agent.name} based on workload."
    )
  end

  private

  def identify_candidates(deal)
    # If deal is linked to an inbox, prefer inbox members
    if deal.inbox
      return deal.inbox.members
    end

    # Otherwise, all agents in the account with access to deals
    # (Assuming all agents have access for now, or filter by role/team)
    deal.account.users.where(account_users: { role: [:agent, :administrator] })
  end
end
