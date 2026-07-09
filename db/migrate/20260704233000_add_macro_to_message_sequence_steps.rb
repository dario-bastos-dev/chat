class AddMacroToMessageSequenceSteps < ActiveRecord::Migration[7.0]
  def change
    add_reference :message_sequence_steps, :macro, foreign_key: { on_delete: :nullify }, null: true
  end
end
