# == Schema Information
#
# Table name: channel_whatsapp_lid_mappings
#
#  id           :bigint           not null, primary key
#  lid          :string           not null
#  phone_number :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  inbox_id     :bigint           not null
#  contact_id   :bigint           not null
#
# Indexes
#
#  index_whatsapp_lid_mappings_on_account_and_lid    (account_id,lid) UNIQUE
#  index_whatsapp_lid_mappings_on_account_and_phone  (account_id,phone_number)
#  index_whatsapp_lid_mappings_on_inbox_and_contact  (inbox_id,contact_id)
#

class Channel::WhatsappLidMapping < ApplicationRecord
  self.table_name = 'channel_whatsapp_lid_mappings'

  belongs_to :account
  belongs_to :inbox
  belongs_to :contact

  validates :lid, presence: true, uniqueness: { scope: :account_id }
  validates :phone_number, presence: true

  # Find a contact by LID within an account
  # Returns the Contact record or nil
  scope :by_lid, ->(account_id, lid) { where(account_id: account_id, lid: lid) }

  # Find all LID mappings for a given phone number
  scope :by_phone, ->(account_id, phone_number) { where(account_id: account_id, phone_number: phone_number) }

  # Create or update a LID mapping
  # Uses upsert to handle race conditions gracefully
  def self.create_or_update_mapping!(lid:, phone_number:, account_id:, inbox_id:, contact_id:)
    # Try to find existing mapping
    mapping = find_by(account_id: account_id, lid: lid)

    if mapping
      # Update if phone or contact changed (e.g., contact was merged)
      if mapping.phone_number != phone_number || mapping.contact_id != contact_id
        mapping.update!(phone_number: phone_number, contact_id: contact_id, inbox_id: inbox_id)
        Rails.logger.info "[LID MAPPING] Updated: #{lid} → #{phone_number} (Contact #{contact_id})"
      end
      return mapping
    end

    # Create new mapping
    mapping = create!(
      lid: lid,
      phone_number: phone_number,
      account_id: account_id,
      inbox_id: inbox_id,
      contact_id: contact_id
    )
    Rails.logger.info "[LID MAPPING] Created: #{lid} → #{phone_number} (Contact #{contact_id})"
    mapping
  rescue ActiveRecord::RecordNotUnique
    # Race condition: another thread created it first — just find and return
    find_by(account_id: account_id, lid: lid)
  end

  # Resolve a LID to a contact within an account
  # Returns { contact:, phone_number: } or nil
  def self.resolve_contact(account_id, lid)
    mapping = find_by(account_id: account_id, lid: lid)
    return nil unless mapping

    { contact: mapping.contact, phone_number: mapping.phone_number, inbox_id: mapping.inbox_id }
  end
end
