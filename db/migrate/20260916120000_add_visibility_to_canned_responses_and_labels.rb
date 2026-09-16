class AddVisibilityToCannedResponsesAndLabels < ActiveRecord::Migration[7.1]
  def change
    add_column :canned_responses, :visibility, :integer, default: 0, null: false
    add_column :canned_responses, :created_by_id, :bigint
    add_column :canned_responses, :team_id, :bigint
    add_index :canned_responses, :created_by_id
    add_index :canned_responses, :team_id

    add_column :labels, :visibility, :integer, default: 0, null: false
    add_column :labels, :created_by_id, :bigint
    add_column :labels, :team_id, :bigint
    add_index :labels, :created_by_id
    add_index :labels, :team_id

    reversible do |dir|
      dir.up do
        execute 'UPDATE canned_responses SET visibility = 2'
        execute 'UPDATE labels SET visibility = 2'
      end
    end
  end
end
