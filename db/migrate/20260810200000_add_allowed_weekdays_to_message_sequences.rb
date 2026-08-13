class AddAllowedWeekdaysToMessageSequences < ActiveRecord::Migration[7.1]
  def change
    add_column :message_sequences, :allowed_weekdays, :integer, array: true, default: [0, 1, 2, 3, 4, 5, 6], null: false
  end
end
