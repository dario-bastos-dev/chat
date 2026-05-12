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

    # Download and attach avatar
    begin
      io = URI.open(avatar_url, open_timeout: 10, read_timeout: 20)
      
      contact.avatar.attach(
        io: io,
        filename: "avatar_#{contact_id}.jpg",
        content_type: 'image/jpeg'
      )
      
      Rails.logger.info "[EVOLUTION_GO AVATAR] ✅ Avatar attached for Contact #{contact_id}"
    rescue StandardError => e
      Rails.logger.error "[EVOLUTION_GO AVATAR] Failed to download avatar from #{avatar_url}: #{e.message}"
    end
  end
end
