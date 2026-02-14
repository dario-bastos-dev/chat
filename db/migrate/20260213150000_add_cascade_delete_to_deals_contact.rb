class AddCascadeDeleteToDealsContact < ActiveRecord::Migration[7.0]
  def up
    # Remove the existing FK constraint that blocks contact deletion
    remove_foreign_key :deals, :contacts

    # Re-add with ON DELETE CASCADE so deleting a contact also deletes its deals
    add_foreign_key :deals, :contacts, on_delete: :cascade
  end

  def down
    remove_foreign_key :deals, :contacts
    add_foreign_key :deals, :contacts
  end
end
