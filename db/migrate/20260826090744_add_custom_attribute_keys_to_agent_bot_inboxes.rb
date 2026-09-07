class AddCustomAttributeKeysToAgentBotInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :agent_bot_inboxes, :conversation_custom_attribute_keys, :string, array: true, default: ['all'], null: false
    add_column :agent_bot_inboxes, :contact_custom_attribute_keys, :string, array: true, default: ['all'], null: false
  end
end
