class FixCascadeDeleteOnLidMappings < ActiveRecord::Migration[7.0]
  def up
    # Remove old FK constraints that use RESTRICT (block deletion)
    remove_foreign_key :channel_whatsapp_lid_mappings, :contacts
    remove_foreign_key :channel_whatsapp_lid_mappings, :inboxes

    # Re-add with ON DELETE CASCADE so deleting a contact/inbox cleans up LID mappings
    add_foreign_key :channel_whatsapp_lid_mappings, :contacts, on_delete: :cascade
    add_foreign_key :channel_whatsapp_lid_mappings, :inboxes, on_delete: :cascade
  end

  def down
    remove_foreign_key :channel_whatsapp_lid_mappings, :contacts
    remove_foreign_key :channel_whatsapp_lid_mappings, :inboxes

    add_foreign_key :channel_whatsapp_lid_mappings, :contacts
    add_foreign_key :channel_whatsapp_lid_mappings, :inboxes
  end
end
