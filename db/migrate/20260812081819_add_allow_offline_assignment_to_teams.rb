class AddAllowOfflineAssignmentToTeams < ActiveRecord::Migration[7.1]
  def change
    add_column :teams, :allow_offline_assignment, :boolean, default: false, null: false
  end
end
