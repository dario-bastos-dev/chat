class AddCadenceFieldsToCampaigns < ActiveRecord::Migration[7.0]
  def change
    add_column :campaigns, :cadence_interval, :integer, default: 2, null: false
    add_column :campaigns, :pause_after, :integer
    add_column :campaigns, :processed_deliveries, :jsonb, default: []
  end
end
