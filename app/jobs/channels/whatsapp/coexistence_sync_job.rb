# Asks Meta to replay the data the business already had in the WhatsApp Business app: the address book
# (`smb_app_state_sync`) and up to 180 days of chats (`history`). Both arrive later as webhooks.
#
# Meta only accepts this within 24h of an embedded signup onboarding and only once per onboarding, so it
# runs right after the webhook callback is registered. Numbers that were never onboarded with coexistence
# are rejected by Meta — that is the expected outcome for them, not an error worth retrying.
class Channels::Whatsapp::CoexistenceSyncJob < ApplicationJob
  queue_as :low

  def perform(whatsapp_channel)
    api_client = Whatsapp::FacebookApiClient.new(whatsapp_channel.provider_config['api_key'])
    phone_number_id = whatsapp_channel.provider_config['phone_number_id']

    api_client.trigger_smb_app_data_sync(phone_number_id, 'smb_app_state_sync')
    api_client.trigger_smb_app_data_sync(phone_number_id, 'history')

    whatsapp_channel.update_history_sync!(status: 'requested', requested_at: Time.current.iso8601, error: nil)
  rescue StandardError => e
    Rails.logger.info("[WHATSAPP COEXISTENCE] Sync unavailable for channel #{whatsapp_channel.id}: #{e.message}")
    whatsapp_channel.update_history_sync!(status: 'unavailable', error: e.message)
  end
end
