class AddExecutionIntervalToMessageSequences < ActiveRecord::Migration[7.0]
  def change
    add_column :message_sequences, :restrict_execution_time, :boolean, default: false
    add_column :message_sequences, :execution_start_hour, :integer, default: 8
    add_column :message_sequences, :execution_end_hour, :integer, default: 19
  end
end
