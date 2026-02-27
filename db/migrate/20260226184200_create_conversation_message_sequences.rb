class CreateConversationMessageSequences < ActiveRecord::Migration[7.0]
  def change
    create_table :conversation_message_sequences do |t|
      t.references :conversation, null: false, foreign_key: true, index: true
      t.references :message_sequence, null: false, foreign_key: true, index: true
      t.boolean :active, default: true
      t.integer :current_step, default: 0
      t.datetime :last_step_executed_at

      t.timestamps
    end

    add_index :conversation_message_sequences,
              [:conversation_id, :message_sequence_id],
              unique: true,
              name: 'idx_conv_msg_seq_uniq'
  end
end
