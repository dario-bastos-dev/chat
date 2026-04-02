class AddMacroSupportToMessageSequences < ActiveRecord::Migration[7.0]
  def change
    add_reference :message_sequences, :macro, foreign_key: true, null: true
    add_column :message_sequences, :macro_execution_time, :integer, default: 0
  end
end
