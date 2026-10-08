class AddAutoAddAssigneeAsParticipantToInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :inboxes, :auto_add_assignee_as_participant, :boolean, default: true, null: false
  end
end
