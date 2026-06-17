class Whatsapp::OneoffCampaignService
  pattr_initialize [:campaign!]

  def perform
    validate_campaign!
    campaign.processing!
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
    audience_list = campaign.normalized_audience
    audience_label_ids = audience_list.select { |audience| audience.is_a?(Hash) && audience['type'] == 'Label' }.map { |a| a['id'] }
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
    audience_list = campaign.normalized_audience
    target_type = audience_list.find { |a| a.is_a?(Hash) && a['type'] == 'Target' }&.dig('value') || 'contacts'
    already_processed = campaign.processed_deliveries || []
    sent_count = 0

    if target_type == 'conversations'
      scope = campaign.account.conversations.where(inbox_id: campaign.inbox_id, status: :open).tagged_with(audience_labels, any: true)
      scope.find_each do |conversation|
        next if already_processed.include?(conversation.id)
        next unless conversation.reload.open?

        process_conversation(conversation)
        already_processed << conversation.id
        campaign.update_column(:processed_deliveries, already_processed)
        sent_count += 1

        remaining_count = already_processed.empty? ? scope.count : scope.where.not(id: already_processed).count
        if remaining_count.zero?
          break
        elsif campaign.pause_after.present? && sent_count >= campaign.pause_after
          campaign.update!(campaign_status: :paused)
          Rails.logger.info "[CAMPAIGN #{campaign.id}] Paused after #{sent_count} deliveries"
          return
        end
        ActiveRecord::Base.connection_pool.release_connection
        sleep(campaign.cadence_interval || 2)
      end
    else
      scope = campaign.account.contacts.tagged_with(audience_labels, any: true)
      scope.find_each do |contact|
        next if already_processed.include?(contact.id)

        process_contact(contact)
        already_processed << contact.id
        campaign.update_column(:processed_deliveries, already_processed)
        sent_count += 1

        remaining_count = already_processed.empty? ? scope.count : scope.where.not(id: already_processed).count
        if remaining_count.zero?
          break
        elsif campaign.pause_after.present? && sent_count >= campaign.pause_after
          campaign.update!(campaign_status: :paused)
          Rails.logger.info "[CAMPAIGN #{campaign.id}] Paused after #{sent_count} deliveries"
          return
        end
        ActiveRecord::Base.connection_pool.release_connection
        sleep(campaign.cadence_interval || 2)
      end
    end

    campaign.update!(campaign_status: :completed)
    Rails.logger.info "Campaign #{campaign.id} processing completed"
  end

  def process_conversation(conversation)
    contact = conversation.contact
    to_phone = conversation.contact_inbox&.source_id.presence || contact.phone_number
    Rails.logger.info "Processing conversation: #{conversation.id} for contact: #{contact.name} (#{to_phone})"

    if to_phone.blank?
      Rails.logger.info "Skipping conversation #{conversation.id} - no phone number"
      return
    end

    requires_template = campaign.inbox.inbox_type != 'API' && !%w[evolution evolution_go].include?(channel.provider)
    if campaign.template_params.blank? && requires_template
      Rails.logger.error "Skipping conversation #{conversation.id} - no template_params found for WhatsApp Business campaign"
      return
    end

    send_whatsapp_template_message(to: to_phone, contact: contact, conversation: conversation)
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

  # Infer Chatwoot file_type from a blob's content_type
  def infer_file_type(blob)
    explicit_type = campaign.trigger_rules&.dig('attachment_file_type')
    return explicit_type.to_sym if explicit_type.present? && %w[image audio video file].include?(explicit_type.to_s)

    content_type = blob.content_type.to_s
    case content_type
    when /\Aimage\// then :image
    when /\Aaudio\// then :audio
    when /\Avideo\// then :video
    else :file
    end
  end

  def send_lite_whatsapp_message(to:, contact:, conversation: nil)
    Rails.logger.info "[WHATSAPP LITE CAMPAIGN] Sending message to #{to} via #{channel.provider}"
    
    if conversation.nil?
      contact_inbox = ContactInbox.find_or_create_by!(
        contact: contact,
        inbox: campaign.inbox,
        source_id: to.to_s.gsub(/^\+/, '')
      )
      conversation = Conversation.where(
        contact_id: contact.id,
        inbox_id: campaign.inbox.id
      ).where.not(status: :resolved).order(created_at: :desc).first

      conversation ||= Conversation.create!(
        contact_id: contact.id,
        inbox_id: campaign.inbox.id,
        account: campaign.account,
        contact_inbox: contact_inbox
      )
    end
    
    conversation.update!(campaign: campaign)
    
    # Build message with a temporary source_id so the after_create_commit
    # SendReplyJob guard (message.source_id.present?) skips re-sending —
    # we already send directly below.
    message = conversation.messages.create!(
      account: campaign.account,
      inbox: campaign.inbox,
      message_type: :outgoing,
      content: campaign.message,
      additional_attributes: { campaign_id: campaign.id },
      source_id: "campaign_pending_#{campaign.id}_#{SecureRandom.hex(4)}"
    )
    
    if campaign.attachments.attached?
      Rails.logger.info "[WHATSAPP LITE CAMPAIGN] Campaign has attachments. Attaching to message..."
      campaign.attachments.each do |active_storage_attachment|
        blob = active_storage_attachment.blob
        next unless blob
        
        Rails.logger.info "[WHATSAPP LITE CAMPAIGN] Attaching blob #{blob.id}..."
        
        # Safely update metadata
        current_metadata = blob.metadata || {}
        blob.update_columns(metadata: current_metadata.merge(analyzed: true)) if current_metadata[:analyzed].blank?
        
        begin
          message_attachment = message.attachments.create!(
            account_id: campaign.account_id,
            file_type: infer_file_type(blob)
          )
          message_attachment.file.attach(blob)
          
          if message_attachment.file.blob
            current_message_metadata = message_attachment.file.blob.metadata || {}
            message_attachment.file.blob.update_columns(metadata: current_message_metadata.merge(analyzed: true))
          else
            Rails.logger.error "[WHATSAPP LITE CAMPAIGN] ❌ message_attachment.file.blob is nil after attach!"
          end
        rescue StandardError => e
          Rails.logger.error "[WHATSAPP LITE CAMPAIGN] ❌ Failed to attach blob #{blob.id}: #{e.message}"
        end
      end
    end

    Rails.logger.info "[WHATSAPP LITE CAMPAIGN] Reloading message..."
    # Reload to pick up the persisted attachments association
    message.reload

    Rails.logger.info "[WHATSAPP LITE CAMPAIGN] Sending via provider service..."
    # Send via Provider Service (Evolution or Evolution GO)
    phone_number = to.to_s.gsub(/^\+/, '')
    message_id = channel.provider_service.send_message(phone_number, message)

    if message_id.present?
      Rails.logger.info "[WHATSAPP LITE CAMPAIGN] ✅ Message sent to #{to}. ID: #{message_id}"
      message.update!(source_id: message_id)
    else
      Rails.logger.error "[WHATSAPP LITE CAMPAIGN] ❌ Failed to send message to #{to}"
      message.update!(status: :failed, external_error: "Failed to send message via WhatsApp Lite Provider")
    end
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP LITE CAMPAIGN] ❌ Error sending to #{to}: #{e.message}"
    Rails.logger.error "[WHATSAPP LITE CAMPAIGN] Backtrace: #{e.backtrace.first(5).join("\n")}"
    message.update!(status: :failed, external_error: "Error: #{e.message}") if message.present?
    nil
  end

  def create_api_message(contact, conversation = nil)
    if conversation.nil?
      conversation = Conversation.where(
        contact_id: contact.id,
        inbox_id: campaign.inbox.id
      ).where.not(status: :resolved).order(created_at: :desc).first

      conversation ||= Conversation.create!(
        contact_id: contact.id,
        inbox_id: campaign.inbox.id,
        account: campaign.account
      )
    end
    conversation.update!(campaign: campaign)
    message = conversation.messages.create!(
      account: campaign.account,
      inbox: campaign.inbox,
      message_type: :outgoing,
      content: campaign.message,
      additional_attributes: { campaign_id: campaign.id },
      source_id: "campaign_pending_#{campaign.id}_#{SecureRandom.hex(4)}"
    )

    if campaign.attachments.attached?
      campaign.attachments.each do |active_storage_attachment|
        blob = active_storage_attachment.blob
        blob.update_columns(metadata: blob.metadata.merge(analyzed: true)) if blob.metadata[:analyzed].blank?
        
        message_attachment = message.attachments.create!(
          account_id: campaign.account_id,
          file_type: infer_file_type(blob)
        )
        message_attachment.file.attach(blob)
        
        message_attachment.file.blob.update_columns(metadata: message_attachment.file.blob.metadata.merge(analyzed: true))
      rescue StandardError => e
        Rails.logger.error "[WHATSAPP API CAMPAIGN] ❌ Failed to attach blob: #{e.message}"
      end
    end
  end
end
