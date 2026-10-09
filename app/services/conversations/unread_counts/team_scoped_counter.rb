# Unread counts for a custom role with conversation_team_manage, which sees its own, the unassigned and its
# teams' conversations (same scope as Conversations::PermissionFilterService). Those sets overlap — a team
# conversation can also be unassigned or the user's own — so they are united by member instead of adding up
# their sizes like the other permission modes do.
class Conversations::UnreadCounts::TeamScopedCounter
  def initialize(account:, user:, inbox_ids:, label_ids:, team_ids:)
    @account = account
    @user = user
    @inbox_ids = inbox_ids
    @label_ids = label_ids
    @team_ids = team_ids
  end

  def perform
    inbox_counts = @inbox_ids.index_with { |inbox_id| visible_in_inbox(inbox_id).size }

    {
      all_count: inbox_counts.values.sum,
      inboxes: positive_counts(inbox_counts),
      labels: positive_counts(@label_ids.index_with { |label_id| label_count(label_id) }),
      teams: positive_counts(@team_ids.index_with { |team_id| team_count(team_id) })
    }
  end

  private

  def visible_in_inbox(inbox_id)
    @visible_in_inbox ||= {}
    @visible_in_inbox[inbox_id] ||= visible_keys(inbox_id).map { |key| members(key) }.reduce(:|)
  end

  def visible_keys(inbox_id)
    [store.inbox_unassigned_key(@account.id, inbox_id), store.inbox_assignee_key(@account.id, inbox_id, @user.id)] +
      @team_ids.map { |team_id| store.team_inbox_key(@account.id, team_id, inbox_id) }
  end

  def label_count(label_id)
    @inbox_ids.sum { |inbox_id| (members(store.label_inbox_key(@account.id, label_id, inbox_id)) & visible_in_inbox(inbox_id)).size }
  end

  # Every conversation of the user's own teams is visible, so the team badge is the whole team set.
  def team_count(team_id)
    @inbox_ids.sum { |inbox_id| members(store.team_inbox_key(@account.id, team_id, inbox_id)).size }
  end

  def members(key)
    members_by_key.fetch(key)
  end

  def members_by_key
    @members_by_key ||= store.members_for_keys(@inbox_ids.flat_map { |inbox_id| inbox_keys(inbox_id) })
  end

  def inbox_keys(inbox_id)
    visible_keys(inbox_id) + @label_ids.map { |label_id| store.label_inbox_key(@account.id, label_id, inbox_id) }
  end

  def positive_counts(counts)
    counts.each_with_object({}) { |(id, count), result| result[id.to_s] = count if count.positive? }
  end

  def store
    ::Conversations::UnreadCounts::Store
  end
end
