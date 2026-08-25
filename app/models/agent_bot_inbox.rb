# == Schema Information
#
# Table name: agent_bot_inboxes
#
#  id                          :bigint           not null, primary key
#  event_names                 :string           default(["conversation_opened", "message_created", "conversation_status_changed", "webwidget_triggered"]), not null, is an Array
#  initial_conversation_status :integer          default("pending"), not null
#  status                      :integer          default("active")
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  account_id                  :integer
#  agent_bot_id                :integer
#  inbox_id                    :integer
#

class AgentBotInbox < ApplicationRecord
  # Event categories the bot can be subscribed to. Each category maps to one or more
  # internal event names dispatched by AgentBotListener.
  CATEGORY_EVENT_MAP = {
    'conversation_opened' => %w[conversation_opened],
    'message_created' => %w[message_created message_updated],
    'conversation_status_changed' => %w[conversation_status_changed conversation_updated conversation_resolved],
    'webwidget_triggered' => %w[webwidget_triggered]
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

  private

  def ensure_account_id
    self.account_id = inbox&.account_id
  end

  def validate_event_names
    return if event_names.to_a.all? { |name| ALL_EVENT_CATEGORIES.include?(name) }

    errors.add(:event_names, 'contains an unsupported event category')
  end
end
