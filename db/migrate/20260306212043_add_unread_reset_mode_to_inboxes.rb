# frozen_string_literal: true

class AddUnreadResetModeToInboxes < ActiveRecord::Migration[7.0]
  def change
    add_column :inboxes, :unread_reset_mode, :integer, default: 0, null: false
  end
end
