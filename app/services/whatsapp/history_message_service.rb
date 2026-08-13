# Imports a single message from a coexistence `history` webhook by reusing the regular Cloud API
# ingestion path (contact resolution, dedup by source_id, attachments, replies), changing only what
# makes a backfilled message different from live traffic.
class Whatsapp::HistoryMessageService < Whatsapp::IncomingMessageWhatsappCloudService
  # The types the parent's attach_files skips: they either carry their own content or, for location,
  # attach right after it runs. Everything else is a media type and gets the fallback below.
  TYPES_WITHOUT_MEDIA = %w[text button interactive location contacts].freeze

  attr_reader :conversation

  private

  # Marks the conversation so its creation callbacks treat it as a backfill: no agent notifications,
  # no conversation_created automations, no auto assignment, and any always-active sequence is
  # attached parked instead of ready to send.
  def conversation_params
    super.merge(additional_attributes: { 'history_sync' => true })
  end

  def create_message(message, source_id: nil, content_attributes_source: message)
    super
    @message.created_at = Time.zone.at(history_timestamp.to_i) if history_timestamp.present?
    @message.status = history_status if history_status
    # Keeps Message's after-create callbacks (notifications, automations, sequences) out of the backfill.
    @message.content_attributes = @message.content_attributes.merge(history_sync: true)
  end

  # Media sent more than 14 days before onboarding is delivered without its asset. Without the blank guard
  # a stripped message raises and, since Meta never resends a chunk, is lost for good; without the fallback
  # it lands as an empty bubble.
  def attach_files
    return super if TYPES_WITHOUT_MEDIA.include?(message_type)

    super if messages_data.first[message_type.to_sym].present?
    return if @message.content.present? || @message.attachments.any?

    @message.content = I18n.t('conversations.messages.whatsapp.unsupported_message')
    @message.content_attributes = @message.content_attributes.merge(is_unsupported: true)
  end

  def download_attachment_file(attachment_payload)
    return if attachment_payload[:id].blank?

    super
  end

  def history_timestamp
    messages_data.first[:timestamp]
  end

  def history_status
    status = messages_data.first.dig(:history_context, :status).to_s.downcase
    status if Message.statuses.key?(status)
  end
end
