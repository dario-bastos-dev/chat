class AddGreetingItemsToInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :inboxes, :greeting_items, :jsonb, default: []
  end
end
