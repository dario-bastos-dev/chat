class Webhooks::EvolutionGoContactAvatarJob < ApplicationJob
  queue_as :low

  def perform(contact_id, channel_id, jid)
    contact = Contact.find_by(id: contact_id)
    channel = Channel::Whatsapp.find_by(id: channel_id)

    return if contact.blank? || channel.blank? || contact.avatar.attached?

    # Get avatar URL from Evolution GO API
    service = Whatsapp::Providers::EvolutionGoService.new(whatsapp_channel: channel)
    avatar_url = service.get_avatar(jid)

    return if avatar_url.blank?

    # The URL is whatever the API returned, so it goes through SafeFetch: scheme is pinned to
    # http/https and the response has to actually be an image.
    begin
      SafeFetch.fetch(avatar_url, allowed_content_type_prefixes: ['image/']) do |result|
        contact.avatar.attach(
          io: result.tempfile,
          filename: "avatar_#{contact_id}.jpg",
          content_type: result.content_type.presence || 'image/jpeg'
        )
      end

      Rails.logger.info "[EVOLUTION_GO AVATAR] Avatar attached for Contact #{contact_id}"
    rescue StandardError => e
      Rails.logger.error "[EVOLUTION_GO AVATAR] Failed to download avatar for Contact #{contact_id}: #{e.class} - #{e.message}"
    end
  end
end
