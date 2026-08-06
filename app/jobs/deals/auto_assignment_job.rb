class Deals::AutoAssignmentJob < ApplicationJob
  queue_as :default

  def perform(deal_id)
    deal = Deal.find_by(id: deal_id)
    return unless deal
    return if deal.assignee_id.present?

    candidates = identify_candidates(deal)
    return if candidates.empty?

    selected_agent = least_loaded(deal.account_id, candidates)
    return unless selected_agent

    deal.update!(assignee: selected_agent)

    deal.deal_activities.create!(
      account: deal.account,
      activity_type: 'note',
      description: "Auto-assigned to #{selected_agent.name} based on workload."
    )
  end

  private

  def identify_candidates(deal)
    # If deal is linked to an inbox, prefer inbox members
    return deal.inbox.members if deal.inbox

    deal.account.users.where(account_users: { role: [:agent, :administrator] })
  end

  # A contagem precisa ser escopada por conta: sem isso, negocios de outras
  # contas influenciavam a distribuicao. Uma unica query agregada substitui o
  # COUNT por candidato.
  def least_loaded(account_id, candidates)
    candidate_ids = candidates.map(&:id)
    loads = Deal.where(account_id: account_id, status: 'open', assignee_id: candidate_ids)
                .group(:assignee_id)
                .count

    candidates.min_by { |user| loads[user.id] || 0 }
  end
end
