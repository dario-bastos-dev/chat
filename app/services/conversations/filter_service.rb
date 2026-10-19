class Conversations::FilterService < FilterService
  ATTRIBUTE_MODEL = 'conversation_attribute'.freeze

  def initialize(params, user, account)
    @account = account
    super(params, user)
  end

  def perform
    validate_query_operator
    @conversations = query_builder(@filters['conversations'])
    mine_count, unassigned_count, all_count, = set_count_for_all_conversations
    assigned_count = all_count - unassigned_count

    {
      conversations: conversations,
      count: {
        mine_count: mine_count,
        assigned_count: assigned_count,
        unassigned_count: unassigned_count,
        all_count: all_count
      }
    }
  end

  def base_relation
    # :messages is deliberately not preloaded: the list payload fetches messages through
    # scoped queries (last message, last_non_activity_message), which bypass the preload.
    conversations = @account.conversations.includes(
      :taggings, :inbox, { assignee: { avatar_attachment: [:blob] } }, { contact: { avatar_attachment: [:blob] } }, :team, :contact_inbox
    )

    Conversations::PermissionFilterService.new(
      conversations,
      @user,
      @account,
      plan_hint_selective_filter: label_filter_present?
    ).perform
  end

  def current_page
    @params[:page] || 1
  end

  def filter_config
    {
      entity: 'Conversation',
      table_name: 'conversations'
    }
  end

  def conversations
    @conversations.sort_on_last_activity_at.page(current_page)
  end

  private

  WHATSAPP_CHAT_TYPES = %w[group individual].freeze

  # Only Evolution GO inboxes hold WhatsApp groups for now, so both answers stay within them: "individual"
  # means the one to one chats of those inboxes, not every non-group conversation of the account.
  def whatsapp_chat_type_filter_query(query_hash)
    chat_type = query_hash['values'].first.to_s
    raise CustomExceptions::CustomFilter::InvalidValue.new(attribute_name: 'whatsapp_chat_type') unless WHATSAPP_CHAT_TYPES.include?(chat_type)

    evolution_go_inboxes = @account.inboxes.where(channel_type: 'Channel::Whatsapp',
                                                  channel_id: Channel::Whatsapp.where(provider: 'evolution_go').select(:id))
    membership = chat_type == 'group' ? 'IN' : 'NOT IN'

    "(conversations.inbox_id IN (#{evolution_go_inboxes.select(:id).to_sql}) " \
      "AND conversations.contact_id #{membership} (#{@account.contacts.whatsapp_groups.select(:id).to_sql})) " \
      "#{query_hash[:query_operator]}"
  end

  ATTENDANCE_VALUES = %w[unattended attended].freeze

  # Read from Conversation.unattended so the filter always matches the sidebar "Unattended" folder. Its columns are
  # only tested with IS NULL / IS NOT NULL, which never yield NULL, so NOT gives exactly the attended conversations.
  def attendance_filter_query(query_hash)
    attendance = query_hash['values'].first.to_s
    raise CustomExceptions::CustomFilter::InvalidValue.new(attribute_name: 'attendance') unless ATTENDANCE_VALUES.include?(attendance)

    unattended = Conversation.unattended.arel.where_sql.delete_prefix('WHERE ')
    condition = attendance == 'unattended' ? "(#{unattended})" : "NOT (#{unattended})"

    "#{condition} #{query_hash[:query_operator]}"
  end

  # The planner hint only pays off when the label condition positively narrows the
  # result set: `equal_to` joined by AND. Negative/presence operators or an OR in the
  # payload leave the result broad, where the inbox index is the better driver.
  def label_filter_present?
    payload = @params[:payload].to_a
    return false if payload.any? { |query_hash| query_hash[:query_operator].to_s.casecmp('or').zero? }

    payload.any? { |query_hash| query_hash[:attribute_key] == 'labels' && query_hash[:filter_operator] == 'equal_to' }
  end
end
