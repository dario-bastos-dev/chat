class AddBehaviourConfigToAgentBotInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :agent_bot_inboxes, :initial_conversation_status, :integer, default: 0, null: false
    add_column :agent_bot_inboxes, :event_names, :string, array: true,
                                                            default: %w[conversation_opened message_created conversation_status_changed webwidget_triggered],
                                                            null: false
  end
end
