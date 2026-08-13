# Ingests the `smb_app_state_sync` webhook: the address book the business keeps in the WhatsApp Business
# app, plus every later change to it. Names saved on the phone are what agents expect to see instead of
# a raw number, so contacts are created and named here even before the person writes in.
#
# Removals are intentionally ignored: a contact deleted from the phone's address book may still hold
# conversations in Chatwoot, and deleting it here would not be recoverable.
class Whatsapp::StateSyncService
  pattr_initialize [:inbox!, :params!]

  def perform
    entries = params.dig(:entry, 0, :changes, 0, :value, :state_sync)
    return if entries.blank?

    Array.wrap(entries).each { |entry| process_entry(entry) }
  end

  private

  def process_entry(entry)
    return unless entry[:type] == 'contact'
    return unless %w[add update].include?(entry[:action])

    contact_params = entry[:contact] || {}
    phone_number = contact_params[:phone_number].to_s.gsub(/\D/, '')
    return if phone_number.blank?

    sync_contact(phone_number, contact_params[:full_name].presence || contact_params[:first_name].presence)
  rescue StandardError => e
    Rails.logger.error("[WHATSAPP STATE SYNC] Failed to sync contact on inbox #{inbox.id}: #{e.message}")
  end

  def sync_contact(phone_number, name)
    formatted_phone_number = "+#{phone_number}"
    contact_inbox = ContactInboxSourceIdResolver.new(
      inbox: inbox,
      source_ids: [source_id(phone_number)],
      contact_attributes: { name: name.presence || formatted_phone_number, phone_number: formatted_phone_number }
    ).perform

    rename_contact(contact_inbox.contact, name, formatted_phone_number)
  end

  def source_id(phone_number)
    Whatsapp::PhoneNumberNormalizationService.new(inbox).normalize_and_find_contact_by_provider(phone_number, :cloud)
  end

  # Only fills in the address book name while the contact is still identified by its number, so a name
  # an agent already corrected in Chatwoot is not overwritten by the phone's copy.
  def rename_contact(contact, name, formatted_phone_number)
    return if name.blank? || contact.name == name
    return unless contact.name == formatted_phone_number || contact.name == TelephoneNumber.parse(formatted_phone_number).international_number

    contact.update!(name: name)
  end
end
