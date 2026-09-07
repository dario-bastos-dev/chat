# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: agent_bot_inboxes
#
#  id                                  :bigint           not null, primary key
#  contact_custom_attribute_keys       :string           default(["all"]), not null, is an Array
#  conversation_custom_attribute_keys  :string           default(["all"]), not null, is an Array
#  event_names                         :string           default(["conversation_opened", "message_created", "conversation_status_changed", "webwidget_triggered"]), not null, is an Array
#  initial_conversation_status         :integer          default("pending"), not null
#  status                              :integer          default("active")
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#  account_id                          :integer
#  agent_bot_id                        :integer
#  inbox_id                            :integer
#
# rubocop:enable Layout/LineLength

class AgentBotInbox < ApplicationRecord
  # Sentinel value meaning "any custom attribute key triggers the event" for
  # conversation_custom_attribute_keys / contact_custom_attribute_keys.
  ALL_CUSTOM_ATTRIBUTES = 'all'.freeze

  # Event categories the bot can be subscribed to. Each category maps to one or more
  # internal event names dispatched by AgentBotListener. `custom_attribute_updated` has no
  # generic event mapping here on purpose: its gating is content-aware (which custom
  # attribute key actually changed) and is handled directly in AgentBotListener.
  CATEGORY_EVENT_MAP = {
    'conversation_opened' => %w[conversation_opened],
    'message_created' => %w[message_created message_updated],
    'conversation_status_changed' => %w[conversation_status_changed conversation_updated conversation_resolved],
    'webwidget_triggered' => %w[webwidget_triggered],
    'custom_attribute_updated' => []
  }.freeze

  ALL_EVENT_CATEGORIES = CATEGORY_EVENT_MAP.keys.freeze

  validates :inbox_id, presence: true
  validates :agent_bot_id, presence: true
  validate :validate_event_names
  before_validation :ensure_account_id

  belongs_to :inbox
  belongs_to :agent_bot
  belongs_to :account
  enum status: { active: 0, inactive: 1 }
  enum initial_conversation_status: { pending: 0, open: 1 }

  def event_enabled?(event_name)
    CATEGORY_EVENT_MAP.slice(*event_names).values.flatten.include?(event_name.to_s)
  end

  def custom_attribute_event_enabled?
    event_names.include?('custom_attribute_updated')
  end

  # model: :conversation or :contact. changed_keys: custom attribute keys that actually changed.
  def notify_for_custom_attribute?(model, changed_keys)
    return false if changed_keys.blank?

    configured_keys = model == :conversation ? conversation_custom_attribute_keys : contact_custom_attribute_keys
    return true if configured_keys.include?(ALL_CUSTOM_ATTRIBUTES)

    configured_keys.intersect?(changed_keys)
  end

  private

  def ensure_account_id
    self.account_id = inbox&.account_id
  end

  def validate_event_names
    return if event_names.to_a.all? { |name| ALL_EVENT_CATEGORIES.include?(name) }

    errors.add(:event_names, 'contains an unsupported event category')
  end
end
