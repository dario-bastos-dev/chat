class ReplaceCurrentStepWithReferenceOnConversationMessageSequences < ActiveRecord::Migration[7.1]
  class MigrationConversationMessageSequence < ActiveRecord::Base
    self.table_name = 'conversation_message_sequences'
  end

  class MigrationMessageSequenceStep < ActiveRecord::Base
    self.table_name = 'message_sequence_steps'
  end

  def up
    add_reference :conversation_message_sequences, :current_step, foreign_key: { to_table: :message_sequence_steps }, null: true
    add_index :conversation_message_sequences, [:active, :waiting_interaction], name: 'index_conv_msg_seq_on_active_and_waiting_interaction'

    MigrationConversationMessageSequence.reset_column_information

    MigrationConversationMessageSequence.find_each do |conv_seq|
      next_step = MigrationMessageSequenceStep
                  .where(message_sequence_id: conv_seq.message_sequence_id)
                  .order(:position)
                  .offset(conv_seq.current_step)
                  .first

      conv_seq.update_column(:current_step_id, next_step&.id)
    end

    remove_column :conversation_message_sequences, :current_step, :integer
  end

  def down
    remove_index :conversation_message_sequences, [:active, :waiting_interaction], name: 'index_conv_msg_seq_on_active_and_waiting_interaction'
    add_column :conversation_message_sequences, :current_step, :integer, default: 0

    MigrationConversationMessageSequence.reset_column_information

    MigrationConversationMessageSequence.find_each do |conv_seq|
      step = MigrationMessageSequenceStep.find_by(id: conv_seq.current_step_id) if conv_seq.current_step_id

      # Quando não há current_step_id, a sequência já havia concluído todos os passos: o índice
      # antigo precisa apontar para além do último passo (offset == total de passos), não para o passo 0.
      position_index = step ? MigrationMessageSequenceStep
        .where(message_sequence_id: conv_seq.message_sequence_id)
        .where('position < ?', step.position)
        .count : MigrationMessageSequenceStep.where(message_sequence_id: conv_seq.message_sequence_id).count

      conv_seq.update_column(:current_step, position_index)
    end

    remove_reference :conversation_message_sequences, :current_step, foreign_key: { to_table: :message_sequence_steps }
  end
end
