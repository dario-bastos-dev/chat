class Conversations::SidebarCounter
  attr_reader :account, :user

  def initialize(account:, user:)
    @account = account
    @user = user
  end

  # Every count comes from a single scan of the open conversations the user can access,
  # since the sidebar refetches them on most realtime conversation events.
  def perform
    counts = open_conversations.pick(
      Arel.sql('COUNT(*)'),
      count_where("conversations.id IN (#{account.mentions.where(user: user).select(:conversation_id).to_sql})"),
      count_where("conversations.id IN (#{participating_conversation_ids.to_sql})"),
      count_where(Conversation.unattended.arel.where_sql.delete_prefix('WHERE '))
    )
    # pick short-circuits to nil on a none relation (custom role without conversation access)
    all_count, mentions_count, participating_count, unattended_count = counts || [0, 0, 0, 0]

    { all_count: all_count, mentions_count: mentions_count, participating_count: participating_count, unattended_count: unattended_count }
  end

  private

  def open_conversations
    Conversations::PermissionFilterService.new(account.conversations.open, user, account).perform
  end

  def participating_conversation_ids
    ConversationParticipant.where(account_id: account.id, user_id: user.id).select(:conversation_id)
  end

  def count_where(condition)
    Arel.sql("COUNT(*) FILTER (WHERE #{condition})")
  end
end
