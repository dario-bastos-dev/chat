# Applies a `message_template_status_update` webhook to the cached templates.
# Templates belong to the WABA, not to a phone number, so every whatsapp_cloud
# channel sharing the business account is updated.
class Whatsapp::TemplateStatusUpdateService
  pattr_initialize [:waba_id!, :event_value!]

  def perform
    return if waba_id.blank? || template_name.blank?

    channels.each { |channel| apply_status(channel) }
  end

  private

  def channels
    Channel::Whatsapp.where(provider: 'whatsapp_cloud')
                     .where("provider_config->>'business_account_id' = ?", waba_id.to_s)
  end

  def template_name
    event_value[:message_template_name] || event_value['message_template_name']
  end

  def template_language
    event_value[:message_template_language] || event_value['message_template_language']
  end

  def status
    event_value[:event] || event_value['event']
  end

  def apply_status(channel)
    templates = channel.message_templates
    return if templates.blank?

    template = find_template(templates)
    return if template.blank? || template['status'] == status

    template['status'] = status
    channel.update_column(:message_templates, templates)
  end

  def find_template(templates)
    templates.find do |template|
      template['name'] == template_name &&
        template['language'].to_s.casecmp?(template_language.to_s)
    end
  end
end
