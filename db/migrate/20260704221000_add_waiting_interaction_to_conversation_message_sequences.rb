class AddWaitingInteractionToConversationMessageSequences < ActiveRecord::Migration[7.0]
  def change
    add_column :conversation_message_sequences, :waiting_interaction, :boolean, default: false, null: false
  end
end
