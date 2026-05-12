class Whatsapp::OneoffCampaignService
  pattr_initialize [:campaign!]

  def perform
    validate_campaign!
    # marks campaign completed so that other jobs won't pick it up
    campaign.completed!
    process_audience(extract_audience_labels)
  end

  private

  delegate :inbox, to: :campaign
  delegate :channel, to: :inbox

  def validate_campaign_type!
    raise "Invalid campaign #{campaign.id}" unless one_off_campaign?
  end

  def one_off_campaign?
    ['Whatsapp', 'API'].include?(campaign.inbox.inbox_type) && campaign.one_off?
  end

  def validate_campaign_status!
    raise 'Completed Campaign' if campaign.completed?
  end

  def validate_provider!
    return if campaign.inbox.inbox_type == 'API'

    # valid source for whatsapp campaign
  end

  def validate_feature_flag!
    raise 'WhatsApp campaigns feature not enabled' unless campaign.account.feature_enabled?(:whatsapp_campaign)
  end

  def validate_campaign!
    validate_campaign_type!
    validate_campaign_status!
    # validate_provider! # Relaxing this as we want to support other providers/inboxes
    validate_feature_flag!
  end

  def extract_audience_labels
    audience_label_ids = campaign.audience.select { |audience| audience['type'] == 'Label' }.pluck('id')
    campaign.account.labels.where(id: audience_label_ids).pluck(:title)
  end

  def process_contact(contact)
    Rails.logger.info "Processing contact: #{contact.name} (#{contact.phone_number})"

    if contact.phone_number.blank?
      Rails.logger.info "Skipping contact #{contact.name} - no phone number"
      return
    end

    # Template params only required for WhatsApp Business (not API or Evolution/Evolution GO)
    requires_template = campaign.inbox.inbox_type != 'API' && !%w[evolution evolution_go].include?(channel.provider)
    if campaign.template_params.blank? && requires_template
      Rails.logger.error "Skipping contact #{contact.name} - no template_params found for WhatsApp Business campaign"
      return
    end

    send_whatsapp_template_message(to: contact.phone_number, contact: contact)
  end

  def process_audience(audience_labels)
    target_type = campaign.audience.find { |a| a['type'] == 'Target' }&.dig('value') || 'contacts'

    if target_type == 'conversations'
      conversations = campaign.account.conversations.where(inbox_id: campaign.inbox_id, status: :open).tagged_with(audience_labels, any: true)
      Rails.logger.info "Processing #{conversations.count} conversations for campaign #{campaign.id}"
      conversations.find_each { |conversation| process_conversation(conversation) }
    else
      contacts = campaign.account.contacts.tagged_with(audience_labels, any: true)
      Rails.logger.info "Processing #{contacts.count} contacts for campaign #{campaign.id}"
      contacts.find_each { |contact| process_contact(contact) }
    end

    Rails.logger.info "Campaign #{campaign.id} processing completed"
  end

  def process_conversation(conversation)
    contact = conversation.contact
    Rails.logger.info "Processing conversation: #{conversation.id} for contact: #{contact.name} (#{contact.phone_number})"

    if contact.phone_number.blank?
      Rails.logger.info "Skipping conversation #{conversation.id} - no phone number"
      return
    end

    requires_template = campaign.inbox.inbox_type != 'API' && !%w[evolution evolution_go].include?(channel.provider)
    if campaign.template_params.blank? && requires_template
      Rails.logger.error "Skipping conversation #{conversation.id} - no template_params found for WhatsApp Business campaign"
      return
    end

    send_whatsapp_template_message(to: contact.phone_number, contact: contact, conversation: conversation)
  end

  def send_whatsapp_template_message(to:, contact:, conversation: nil)
    # API inbox type uses simple messages
    if campaign.inbox.inbox_type == 'API'
      create_api_message(contact, conversation)
      return
    end

    # Evolution / Evolution GO (WhatsApp Lite) uses simple messages, not templates
    if %w[evolution evolution_go].include?(channel.provider)
      send_lite_whatsapp_message(to: to, contact: contact, conversation: conversation)
      return
    end

    # WhatsApp Business uses templates
    processor = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: campaign.template_params
    )

    name, namespace, lang_code, processed_parameters = processor.call

    return if name.blank?

    channel.send_template(to, {
                            name: name,
                            namespace: namespace,
                            lang_code: lang_code,
                            parameters: processed_parameters
                          }, nil)

  rescue StandardError => e
    Rails.logger.error "Failed to send WhatsApp template message to #{to}: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}"
    # continue processing remaining contacts
    nil
  end

  def send_lite_whatsapp_message(to:, contact:, conversation: nil)
    Rails.logger.info "[WHATSAPP LITE CAMPAIGN] Sending message to #{to} via #{channel.provider}"
    
    if conversation.nil?
      # Create or find conversation for this contact
      contact_inbox = ContactInbox.find_or_create_by!(
        contact: contact,
        inbox: campaign.inbox,
        source_id: to.to_s.gsub(/^\+/, '')
      )
      
      conversation = Conversation.where(
        contact_id: contact.id,
        inbox_id: campaign.inbox.id
      ).order(created_at: :desc).first_or_create!(
        account: campaign.account,
        contact_inbox: contact_inbox
      )
    end
    
    conversation.update!(campaign: campaign)
    
    message = Message.new(
      conversation: conversation,
      account: campaign.account,
      inbox: campaign.inbox,
      message_type: :outgoing,
      content: campaign.message,
      additional_attributes: { campaign_id: campaign.id }
    )
    
    if campaign.attachments.attached?
      campaign.attachments.each do |attachment|
        message.attachments.attach(attachment.blob)
      end
    end

    message.save!
    
    # Send via Provider Service (Evolution or Evolution GO)
    phone_number = to.to_s.gsub(/^\+/, '')
    message_id = channel.provider_service.send_message(phone_number, message)
    
    if message_id.present?
      message.update!(source_id: message_id)
      Rails.logger.info "[WHATSAPP LITE CAMPAIGN] ✅ Message sent to #{to}, ID: #{message_id}"
    else
      Rails.logger.error "[WHATSAPP LITE CAMPAIGN] ❌ Failed to send message to #{to}"
    end
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP LITE CAMPAIGN] ❌ Error sending to #{to}: #{e.message}"
    Rails.logger.error "[WHATSAPP LITE CAMPAIGN] Backtrace: #{e.backtrace.first(5).join("\n")}"
    nil
  end

  def create_api_message(contact, conversation = nil)
    conversation ||= Conversation.where(contact_id: contact.id, inbox_id: campaign.inbox.id).first_or_create!
    conversation.update!(campaign: campaign)
    message = Message.new(
      conversation: conversation,
      account: campaign.account,
      inbox: campaign.inbox,
      message_type: :outgoing,
      content: campaign.message,
      additional_attributes: { campaign_id: campaign.id }
    )

    if campaign.attachments.attached?
      campaign.attachments.each do |attachment|
        message.attachments.attach(attachment.blob)
      end
    end

    message.save!
  end
end
