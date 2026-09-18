class MessageTemplates::HookExecutionService
  pattr_initialize [:message!]

  def perform
    return if conversation.last_incoming_message.blank?
    return if message.auto_reply_email?

    trigger_templates
  end

  private

  delegate :inbox, :conversation, to: :message
  delegate :contact, to: :conversation

  def trigger_templates
    if should_send_out_of_office_message? && !withheld_from_group?('out_of_office_in_groups')
      ::MessageTemplates::Template::OutOfOffice.new(conversation: conversation).perform
    end
    if should_send_greeting? && !withheld_from_group?('greeting_in_groups')
      ::MessageTemplates::Template::Greeting.new(conversation: conversation).perform
    end
    ::MessageTemplates::Template::EmailCollect.new(conversation: conversation).perform if inbox.enable_email_collect && should_send_email_collect?
  end

  def should_send_out_of_office_message?
    return false if conversation.campaign.present?
    # should not send if its a tweet message
    return false if conversation.tweet?
    # should not send for outbound messages
    return false unless message.incoming?
    # a tapped CSAT flow button answers a question we asked, replying "we are closed" to it is noise
    return false if message.csat_flow_reply?
    # prevents sending out-of-office message if an agent has sent a message in last 5 minutes
    # ensures better UX by not interrupting active conversations at the end of business hours
    return false if conversation.messages.outgoing.where(private: false).exists?(['created_at > ?', 5.minutes.ago])

    inbox.out_of_office? && conversation.messages.today.template.empty? && inbox.out_of_office_message.present?
  end

  def first_message_from_contact?
    conversation.messages.outgoing.count.zero? && conversation.messages.template.count.zero?
  end

  def should_send_greeting?
    return false if conversation.campaign.present?
    # should not send if its a tweet message
    return false if conversation.tweet?

    first_message_from_contact? && inbox.greeting_enabled? && inbox.greeting_message.present?
  end

  # The greeting and the away message are written for one person ("tell us your name", "we will get
  # back to you"), so a group only gets each of them once the inbox allows it by its own setting.
  def withheld_from_group?(setting)
    return false unless contact.whatsapp_group?

    ['true', true].exclude?(inbox.channel.try(:provider_config)&.dig(setting))
  end

  def email_collect_was_sent?
    conversation.messages.where(content_type: 'input_email').present?
  end

  # TODO: we should be able to reduce this logic once we have a toggle for email collect messages
  def should_send_email_collect?
    return false if conversation.campaign.present?

    !contact_has_email? && inbox.web_widget? && !email_collect_was_sent?
  end

  def contact_has_email?
    contact.email
  end
end
MessageTemplates::HookExecutionService.prepend_mod_with('MessageTemplates::HookExecutionService')
