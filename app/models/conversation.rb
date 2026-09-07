# == Schema Information
#
# Table name: conversations
#
#  id                     :integer          not null, primary key
#  additional_attributes  :jsonb
#  agent_last_seen_at     :datetime
#  assignee_last_seen_at  :datetime
#  cached_label_list      :text
#  contact_last_seen_at   :datetime
#  custom_attributes      :jsonb
#  first_reply_created_at :datetime
#  identifier             :string
#  last_activity_at       :datetime         not null
#  priority               :integer
#  snoozed_until          :datetime
#  status                 :integer          default("open"), not null
#  status_changed_at      :datetime
#  uuid                   :uuid             not null
#  waiting_since          :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :integer          not null
#  assignee_agent_bot_id  :bigint
#  assignee_id            :integer
#  campaign_id            :bigint
#  contact_id             :bigint
#  contact_inbox_id       :bigint
#  display_id             :integer          not null
#  inbox_id               :integer          not null
#  sla_policy_id          :bigint
#  team_id                :bigint
#
# Indexes
#
#  conv_acid_inbid_stat_asgnid_idx                    (account_id,inbox_id,status,assignee_id)
#  index_conversations_on_account_id                  (account_id)
#  index_conversations_on_account_id_and_display_id   (account_id,display_id) UNIQUE
#  index_conversations_on_assignee_id_and_account_id  (assignee_id,account_id)
#  index_conversations_on_campaign_id                 (campaign_id)
#  index_conversations_on_contact_id                  (contact_id)
#  index_conversations_on_contact_inbox_id            (contact_inbox_id)
#  index_conversations_on_created_at                  (created_at)
#  index_conversations_on_first_reply_created_at      (first_reply_created_at)
#  index_conversations_on_id_and_account_id           (account_id,id)
#  index_conversations_on_identifier_and_account_id   (identifier,account_id)
#  index_conversations_on_inbox_id                    (inbox_id)
#  index_conversations_on_priority                    (priority)
#  index_conversations_on_status_and_account_id       (status,account_id)
#  index_conversations_on_status_and_priority         (status,priority)
#  index_conversations_on_team_id                     (team_id)
#  index_conversations_on_uuid                        (uuid) UNIQUE
#  index_conversations_on_waiting_since               (waiting_since)
#

class Conversation < ApplicationRecord
  include Labelable
  include LlmFormattable
  include AssignmentHandler
  include AutoAssignmentHandler
  include ActivityMessageHandler
  include UrlHelper
  include SortHandler
  include PushDataHelper
  include ConversationMuteHelpers

  # How long a tapped CSAT flow button keeps silencing repeats of the same answer after the flow has
  # been answered. WhatsApp keeps the buttons tappable, so a second tap is a repeat, not a new message.
  CSAT_FLOW_ANSWERED_SILENCE = 10.minutes

  CONVERSATION_UPDATED_ADDITIONAL_ATTRIBUTE_KEYS = %w[conversation_language].freeze
  FILTERED_UNREAD_COUNT_ADDITIONAL_ATTRIBUTE_KEYS = %w[browser_language conversation_language mail_subject referer].freeze
  FILTERED_UNREAD_COUNT_UPDATE_KEYS = %w[
    cached_label_list campaign_id custom_attributes first_reply_created_at label_list last_activity_at priority snoozed_until waiting_since
  ].freeze
  private_constant :CONVERSATION_UPDATED_ADDITIONAL_ATTRIBUTE_KEYS, :FILTERED_UNREAD_COUNT_ADDITIONAL_ATTRIBUTE_KEYS,
                   :FILTERED_UNREAD_COUNT_UPDATE_KEYS

  validates :account_id, presence: true
  validates :inbox_id, presence: true
  validates :contact_id, presence: true
  before_validation :validate_additional_attributes
  before_validation :reset_agent_bot_when_assignee_present
  validates :additional_attributes, jsonb_attributes_length: true
  validates :custom_attributes, jsonb_attributes_length: true
  validates :uuid, uniqueness: true
  validate :validate_referer_url

  enum status: { open: 0, resolved: 1, pending: 2, snoozed: 3 }
  enum priority: { low: 0, medium: 1, high: 2, urgent: 3 }

  scope :unassigned, -> { where(assignee_id: nil) }
  scope :assigned, -> { where.not(assignee_id: nil) }
  scope :assigned_to, ->(agent) { where(assignee_id: agent.id) }
  scope :sort_on_unread, lambda { |_direction|
    order(unread_messages_count_arel.desc).sort_on_last_activity_at('desc')
  }
  scope :unattended, -> { where(first_reply_created_at: nil).or(where.not(waiting_since: nil)) }
  scope :resolvable_not_waiting, lambda { |auto_resolve_after|
    return none if auto_resolve_after.to_i.zero?

    open.where('last_activity_at < ? AND waiting_since IS NULL', Time.now.utc - auto_resolve_after.minutes)
  }
  scope :resolvable_all, lambda { |auto_resolve_after|
    return none if auto_resolve_after.to_i.zero?

    open.where('last_activity_at < ?', Time.now.utc - auto_resolve_after.minutes)
  }

  scope :last_user_message_at, lambda {
    joins(
      "INNER JOIN (#{last_messaged_conversations.to_sql}) AS grouped_conversations
      ON grouped_conversations.conversation_id = conversations.id"
    ).sort_on_last_user_message_at
  }

  belongs_to :account
  belongs_to :inbox
  belongs_to :assignee, class_name: 'User', optional: true, inverse_of: :assigned_conversations
  belongs_to :assignee_agent_bot, class_name: 'AgentBot', optional: true
  belongs_to :contact
  belongs_to :contact_inbox
  belongs_to :team, optional: true
  belongs_to :campaign, optional: true

  has_many :mentions, dependent: :destroy_async
  has_many :messages, dependent: :destroy_async, autosave: true
  has_one :csat_survey_response, dependent: :destroy_async
  has_many :conversation_participants, dependent: :destroy_async
  has_many :notifications, as: :primary_actor, dependent: :destroy_async
  has_many :attachments, through: :messages
  has_many :reporting_events, dependent: :destroy_async
  has_many :conversation_deals, dependent: :destroy
  has_many :deals, through: :conversation_deals
  has_many :scheduled_messages, dependent: :destroy
  has_many :conversation_message_sequences, dependent: :destroy
  has_many :active_message_sequences, through: :conversation_message_sequences, source: :message_sequence
  has_many :automation_rule_pending_executions, dependent: :delete_all

  before_save :ensure_snooze_until_reset
  before_save :set_status_changed_at
  before_create :determine_conversation_status
  before_create :ensure_waiting_since

  after_update_commit :execute_after_update_commit_callbacks
  after_create_commit :notify_conversation_creation, unless: :history_sync?
  after_create_commit :load_attributes_created_by_db_triggers
  after_create_commit :attach_always_active_sequences

  delegate :auto_resolve_after, to: :account

  def can_reply?
    Conversations::MessageWindowService.new(self).can_reply?
  end

  def language
    additional_attributes&.dig('conversation_language')
  end

  # Be aware: The precision of created_at and last_activity_at may differ from Ruby's Time precision.
  # Our DB column (see schema) stores timestamps with second-level precision (no microseconds), so
  # if you assign a Ruby Time with microseconds, the DB will truncate it. This may cause subtle differences
  # if you compare or copy these values in Ruby, also in our specs
  # So in specs rely on to be_with(1.second) instead of to eq()
  # TODO: Migrate to use a timestamp with microsecond precision
  def last_activity_at
    self[:last_activity_at] || created_at
  end

  def last_incoming_message
    messages.where(account_id: account_id)&.incoming&.last
  end

  def toggle_status
    # FIXME: implement state machine with aasm
    self.status = open? ? :resolved : :open
    self.status = :open if pending? || snoozed?
    save
  end

  def toggle_priority(priority = nil)
    self.priority = priority.presence
    save
  end

  def bot_handoff!(dispatch_event: true)
    update(waiting_since: Time.current) if waiting_since.blank?
    self.assignee_agent_bot = nil
    open!
    dispatch_bot_handoff_event if dispatch_event
  end

  def dispatch_bot_handoff_event
    dispatcher_dispatch(CONVERSATION_BOT_HANDOFF)
  end

  def unread_messages
    agent_last_seen_at.present? ? messages.created_since(agent_last_seen_at) : messages
  end

  def assignee_unread_messages
    assignee_last_seen_at.present? ? messages.created_since(assignee_last_seen_at) : messages
  end

  def unread_incoming_messages
    unread_messages.where(account_id: account_id).incoming.last(10)
  end

  def cached_label_list_array
    (cached_label_list || '').split(',').map(&:strip)
  end

  def notifiable_assignee_change?
    return false unless saved_change_to_assignee_id?
    return false if assignee_id.blank?
    return false if self_assign?(assignee_id)

    true
  end

  # Virtual attribute till we switch completely to polymorphic assignee
  def assignee_type
    return 'AgentBot' if assignee_agent_bot_id.present?
    return 'User' if assignee_id.present?

    nil
  end

  def assigned_entity
    assignee_agent_bot || assignee
  end

  def tweet?
    inbox.inbox_type == 'Twitter' && additional_attributes['type'] == 'tweet'
  end

  def self.unread_messages_count_arel
    messages = Message.arel_table
    conversations = arel_table
    unread_messages = messages
                      .project(messages[:id].count)
                      .where(unread_messages_condition(messages, conversations))

    Arel::Nodes::Grouping.new(unread_messages.ast)
  end

  def self.unread_messages_condition(messages, conversations)
    messages[:conversation_id].eq(conversations[:id])
                              .and(messages[:account_id].eq(conversations[:account_id]))
                              .and(messages[:message_type].eq(Message.message_types[:incoming]))
                              .and(
                                conversations[:agent_last_seen_at].eq(nil)
                                  .or(messages[:created_at].gt(conversations[:agent_last_seen_at]))
                              )
  end

  def recent_messages
    messages.chat.last(5)
  end

  def csat_survey_link
    "#{ENV.fetch('FRONTEND_URL', nil)}/survey/responses/#{uuid}"
  end

  # The CSAT flow parks what it is waiting for on the conversation so that a tapped button can be
  # recognised inside Message's create callbacks, before any listener runs.
  def csat_flow_state
    state = additional_attributes&.dig('csat_flow')
    return {} if state.blank? || Time.zone.parse(state['expires_at']) < Time.current

    state
  end

  def store_csat_flow_state!(stage:, message:, silent:, button_index: nil)
    state = { 'stage' => stage, 'message_id' => message.id, 'silent' => silent,
              'button_index' => button_index, 'expires_at' => 24.hours.from_now.iso8601 }
    update!(additional_attributes: (additional_attributes || {}).merge('csat_flow' => state))
  end

  # Answering ends the flow but keeps the silence for a while: WhatsApp leaves the buttons tappable
  # and a second tap arrives as a repeat of the same answer. Past that window the same words are
  # taken as a new message from the contact, so nothing they write is ever swallowed for long.
  def close_csat_flow_state!
    state = additional_attributes&.dig('csat_flow')
    return if state.blank?

    answered = state.merge('answered_at' => Time.current.iso8601)
    update!(additional_attributes: additional_attributes.merge('csat_flow' => answered))
  end

  def clear_csat_flow_state!
    return if additional_attributes&.dig('csat_flow').blank?

    update!(additional_attributes: additional_attributes.except('csat_flow'))
  end

  # Answering the flow is not the contact coming back for help, so it must not reopen the
  # conversation. Only the buttons the admin left as plain answers are silenced: one that reopens
  # the conversation on purpose is absent from the list and takes the regular path.
  def csat_flow_silent_reply?(content)
    state = csat_flow_state
    answered_at = state['answered_at']
    return false if answered_at.present? && Time.zone.parse(answered_at) < CSAT_FLOW_ANSWERED_SILENCE.ago

    state['silent'].to_a.include?(CsatFlowService.normalize(content))
  end

  def dispatch_conversation_updated_event(previous_changes = nil)
    dispatcher_dispatch(CONVERSATION_UPDATED, previous_changes)
  end

  private

  def execute_after_update_commit_callbacks
    handle_resolved_status_change
    notify_status_change
    create_activity
    invalidate_filtered_unread_count_conversation
    notify_conversation_updation
  end

  def handle_resolved_status_change
    # When conversation is resolved, clear waiting_since using update_column to avoid callbacks
    return unless saved_change_to_status? && status == 'resolved'

    # rubocop:disable Rails/SkipsModelValidations
    update_column(:waiting_since, nil)
    scheduled_messages.pending.update_all(status: :cancelled)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def ensure_snooze_until_reset
    self.snoozed_until = nil unless snoozed?
  end

  def set_status_changed_at
    self.status_changed_at = Time.current if new_record? || status_changed?
  end

  def ensure_waiting_since
    self.waiting_since = created_at
  end

  def validate_additional_attributes
    self.additional_attributes = {} unless additional_attributes.is_a?(Hash)
  end

  def reset_agent_bot_when_assignee_present
    return if assignee_id.blank?

    self.assignee_agent_bot_id = nil
  end

  def determine_conversation_status
    self.status = :resolved and return if contact.blocked?

    return handle_campaign_status if campaign.present?

    set_active_bot_conversation if inbox.active_bot?
  end

  def handle_campaign_status
    set_active_bot_conversation if campaign.sender_id.nil? && inbox.active_bot?
  end

  def set_active_bot_conversation
    agent_bot_inbox = inbox.agent_bot_inbox
    # Only honor the configured initial status when this AgentBotInbox is the one actually
    # driving the bot flow; an inactive/stale record must not affect other bot types
    # (Dialogflow, Captain) that may be the real reason inbox.active_bot? is true.
    self.status = agent_bot_inbox&.active? ? agent_bot_inbox.initial_conversation_status : 'pending'
    return unless agent_bot_inbox&.active? && assignee_id.blank?

    self.assignee_agent_bot = inbox.agent_bot
  end

  # Conversations rebuilt from WhatsApp coexistence history are months old, so they must not be treated as
  # live activity: no agent notifications, no conversation_created automations, no auto assignment, and
  # any always-active sequence is attached parked instead of ready to send.
  def history_sync?
    additional_attributes['history_sync'].present?
  end

  def notify_conversation_creation
    dispatcher_dispatch(CONVERSATION_CREATED)
  end

  def notify_conversation_updation
    return unless previous_changes.keys.present? && allowed_keys?

    dispatch_conversation_updated_event(previous_changes)
  end

  def list_of_keys
    %w[team_id assignee_id assignee_agent_bot_id status snoozed_until custom_attributes label_list waiting_since
       first_reply_created_at priority]
  end

  def allowed_keys?
    previous_changes.keys.intersect?(list_of_keys) ||
      additional_attributes_changed?(CONVERSATION_UPDATED_ADDITIONAL_ATTRIBUTE_KEYS)
  end

  def invalidate_filtered_unread_count_conversation
    return unless filtered_unread_count_update?

    ::Conversations::UnreadCounts::FilteredCountInvalidator.new(account).conversation_changed!
  end

  def filtered_unread_count_update?
    previous_changes.keys.intersect?(FILTERED_UNREAD_COUNT_UPDATE_KEYS) ||
      additional_attributes_changed?(FILTERED_UNREAD_COUNT_ADDITIONAL_ATTRIBUTE_KEYS)
  end

  def additional_attributes_changed?(keys)
    Array(previous_changes['additional_attributes']).compact.any? { |attributes| attributes.keys.intersect?(keys) }
  end

  def load_attributes_created_by_db_triggers
    # Display id is set via a trigger in the database
    # So we need to specifically fetch it after the record is created
    # We can't use reload because it will clear the previous changes, which we need for the dispatcher
    obj_from_db = self.class.find(id)
    self[:display_id] = obj_from_db[:display_id]
    self[:uuid] = obj_from_db[:uuid]
  end

  def notify_status_change
    {
      CONVERSATION_OPENED => -> { saved_change_to_status? && open? },
      CONVERSATION_RESOLVED => -> { saved_change_to_status? && resolved? },
      CONVERSATION_STATUS_CHANGED => -> { saved_change_to_status? },
      CONVERSATION_READ => -> { saved_change_to_contact_last_seen_at? },
      CONVERSATION_CONTACT_CHANGED => -> { saved_change_to_contact_id? }
    }.each do |event, condition|
      condition.call && dispatcher_dispatch(event, status_change)
    end
  end

  def dispatcher_dispatch(event_name, changed_attributes = nil)
    Rails.configuration.dispatcher.dispatch(event_name, Time.zone.now, conversation: self, notifiable_assignee_change: notifiable_assignee_change?,
                                                                       changed_attributes: changed_attributes,
                                                                       performed_by: Current.executed_by)
  end

  def conversation_status_changed_to_open?
    return false unless open?
    # saved_change_to_status? method only works in case of update
    return true if previous_changes.key?(:id) || saved_change_to_status?
  end

  def create_label_change(user_name)
    return unless user_name

    previous_labels, current_labels = previous_changes[:label_list]
    return unless (previous_labels.is_a? Array) && (current_labels.is_a? Array)
    
    added_labels = current_labels - previous_labels

    create_label_added(user_name, added_labels)
    create_label_removed(user_name, previous_labels - current_labels)

    attach_tag_sequences(added_labels) if added_labels.any?
  end

  def attach_tag_sequences(added_labels)
    # Ignora eventos se a conversa nao puder receber funil 
    return if resolved?
    
    downcased_added = added_labels.map(&:downcase)

    account.message_sequences.active.tag.find_each do |sequence|
      # Validar inboxes
      valid_inboxes = sequence.selected_inboxes? ? sequence.inbox_ids : account.inboxes.pluck(:id)
      next unless valid_inboxes.include?(inbox_id)

      # Pegar a lista de tags configuradas para o disparo da sequência
      seq_tags = sequence.activation_tag.to_s.split(',').compact_blank.map { |t| t.strip.downcase }
      
      # Verifica se alguma tag que acabou de ser adicionada bate com os gatilhos esperados
      next unless (seq_tags & downcased_added).any?

      # Encontrar ou atrelar e resetar (como na nova regra definida de recomeçar a sequência)
      conv_seq = conversation_message_sequences.find_or_initialize_by(message_sequence_id: sequence.id)
      
      # Se estava inativa ou é a primeira vez, bota no primeiro passo e ativa pro Cronjob passar listando!
      if conv_seq.new_record? || !conv_seq.active?
        conv_seq.active = true
        conv_seq.current_step = sequence.steps.order(:position).first
        conv_seq.last_step_executed_at = nil
      end

      conv_seq.save! if conv_seq.changed? || conv_seq.new_record?
    end
  end

  def validate_referer_url
    return unless additional_attributes['referer']

    self['additional_attributes']['referer'] = nil unless url_valid?(additional_attributes['referer'])
  end

  def attach_always_active_sequences
    account.message_sequences.active.always_active.find_each do |sequence|
      conversation_message_sequences.find_or_create_by!(message_sequence_id: sequence.id) do |cms|
        cms.active = true
        # A conversation rebuilt from WhatsApp history is dormant, so the sequence is attached but parked:
        # `ready_for_execution` skips it, and MessageSequenceListener resumes it counting from the moment
        # the contact writes again. Attaching it as ready would send follow-ups about a months old chat.
        cms.waiting_interaction = history_sync?
        cms.current_step = sequence.steps.order(:position).first
      end
    end
  rescue StandardError => e
    Rails.logger.error("[ConversationMessageSequence] Failed to auto-attach sequences: #{e.message}")
  end

  # creating db triggers
  trigger.before(:insert).for_each(:row) do
    "NEW.display_id := nextval('conv_dpid_seq_' || NEW.account_id);"
  end
end

Conversation.include_mod_with('Audit::Conversation')
Conversation.include_mod_with('Concerns::Conversation')
Conversation.prepend_mod_with('Conversation')
