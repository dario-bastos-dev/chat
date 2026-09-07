class AddBehaviourConfigToAgentBotInboxes < ActiveRecord::Migration[7.1]
  DEFAULT_EVENT_NAMES = %w[
    conversation_opened message_created conversation_status_changed webwidget_triggered
  ].freeze

  def change
    add_column :agent_bot_inboxes, :initial_conversation_status, :integer, default: 0, null: false
    add_column :agent_bot_inboxes, :event_names, :string, array: true, default: DEFAULT_EVENT_NAMES, null: false
  end
end
