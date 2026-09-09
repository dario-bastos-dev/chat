class AgentBotListener < BaseListener
  def conversation_resolved(event)
    conversation = extract_conversation_and_account(event)[0]
    inbox = conversation.inbox
    event_name = __method__.to_s
    return unless event_enabled_for_inbox?(inbox, event_name)

    payload = conversation.webhook_data.merge(event: event_name)
    agent_bots_for(inbox, conversation).each { |agent_bot| process_webhook_bot_event(agent_bot, payload) }
  end

  def conversation_opened(event)
    conversation = extract_conversation_and_account(event)[0]
    inbox = conversation.inbox
    event_name = __method__.to_s
    return unless event_enabled_for_inbox?(inbox, event_name)

    payload = conversation.webhook_data.merge(event: event_name)
    agent_bots_for(inbox, conversation).each { |agent_bot| process_webhook_bot_event(agent_bot, payload) }
  end

  def conversation_status_changed(event)
    conversation = extract_conversation_and_account(event)[0]
    changed_attributes = extract_changed_attributes(event)
    inbox = conversation.inbox
    event_name = __method__.to_s
    return unless event_enabled_for_inbox?(inbox, event_name)

    payload = conversation.webhook_data.merge(event: event_name, changed_attributes: changed_attributes)
    agent_bots_for(inbox, conversation).each { |agent_bot| process_webhook_bot_event(agent_bot, payload) }
  end

  def conversation_updated(event)
    conversation = extract_conversation_and_account(event)[0]
    inbox = conversation.inbox
    event_name = __method__.to_s
    agent_bot_inbox = inbox.agent_bot_inbox

    general_update_enabled = event_enabled_for_inbox?(inbox, event_name)
    custom_attribute_match = custom_attribute_category_matches?(agent_bot_inbox, :conversation, event)
    return unless general_update_enabled || custom_attribute_match

    changed_attributes = extract_changed_attributes(event)
    payload = conversation.webhook_data.merge(event: event_name, changed_attributes: changed_attributes)
    agent_bots_for(inbox, conversation).each { |agent_bot| process_webhook_bot_event(agent_bot, payload) }
  end

  def message_created(event)
    message = extract_message_and_account(event)[0]
    inbox = message.inbox
    return unless message.webhook_sendable?

    method_name = __method__.to_s
    return unless event_enabled_for_inbox?(inbox, method_name)

    agent_bots_for(inbox, message.conversation).each { |agent_bot| process_message_event(method_name, agent_bot, message, event) }
  end

  def message_updated(event)
    message = extract_message_and_account(event)[0]
    inbox = message.inbox
    return unless message.webhook_sendable?

    method_name = __method__.to_s
    return unless event_enabled_for_inbox?(inbox, method_name)

    agent_bots_for(inbox, message.conversation).each { |agent_bot| process_message_event(method_name, agent_bot, message, event) }
  end

  def contact_updated(event)
    # contact_updated fires on every contact save (name, avatar, last_seen, etc.), most of
    # which never touch custom_attributes. Bail out before querying inboxes for the common case.
    changed_keys = changed_custom_attribute_keys(event)
    return if changed_keys.empty?

    contact = extract_contact_and_account(event)[0]
    changed_attributes = extract_changed_attributes(event)

    contact.inboxes.distinct.each do |inbox|
      next unless custom_attribute_notifiable?(inbox.agent_bot_inbox, :contact, changed_keys)

      payload = contact.webhook_data.merge(event: __method__.to_s, changed_attributes: changed_attributes)
      agent_bots_for(inbox).each { |agent_bot| process_webhook_bot_event(agent_bot, payload) }
    end
  end

  def webwidget_triggered(event)
    contact_inbox = event.data[:contact_inbox]
    inbox = contact_inbox.inbox
    event_name = __method__.to_s
    return unless event_enabled_for_inbox?(inbox, event_name)

    payload = contact_inbox.webhook_data.merge(event: event_name)
    payload[:event_info] = event.data[:event_info]
    agent_bots_for(inbox).each { |agent_bot| process_webhook_bot_event(agent_bot, payload) }
  end

  private

  def event_enabled_for_inbox?(inbox, event_name)
    agent_bot_inbox = inbox.agent_bot_inbox
    return true unless agent_bot_inbox&.active?

    agent_bot_inbox.event_enabled?(event_name)
  end

  # Gates conversation_updated/contact_updated on the `custom_attribute_updated` category:
  # only true when that category is enabled AND at least one of the custom attribute keys
  # that actually changed is covered by the bot's configured key list (or "all").
  def custom_attribute_category_matches?(agent_bot_inbox, model, event)
    custom_attribute_notifiable?(agent_bot_inbox, model, changed_custom_attribute_keys(event))
  end

  def custom_attribute_notifiable?(agent_bot_inbox, model, changed_keys)
    return false unless agent_bot_inbox&.active?
    return false unless agent_bot_inbox.custom_attribute_event_enabled?

    agent_bot_inbox.notify_for_custom_attribute?(model, changed_keys)
  end

  def changed_custom_attribute_keys(event)
    previous_value, current_value = event.data[:changed_attributes]&.dig('custom_attributes')
    return [] if previous_value.blank? && current_value.blank?

    previous_value = previous_value.presence || {}
    current_value = current_value.presence || {}
    (previous_value.keys | current_value.keys).reject { |key| previous_value[key] == current_value[key] }
  end

  def agent_bots_for(inbox, conversation = nil)
    return [] if bot_silenced_in_group?(inbox, conversation)

    bots = []
    bots << conversation.assignee_agent_bot if conversation&.assignee_agent_bot.present?
    inbox_bot = active_inbox_agent_bot(inbox)
    bots << inbox_bot if inbox_bot.present?
    bots.compact.uniq
  end

  # A group chat is a room full of people talking to each other. A bot wired for one to one support
  # would answer every participant, so it stays out until the inbox asks for it. This is the single
  # place every bot event passes through, so guarding here covers all of them at once.
  def bot_silenced_in_group?(inbox, conversation)
    return false unless conversation&.contact&.whatsapp_group?

    ['true', true].exclude?(inbox.channel.try(:provider_config)&.dig('bot_in_groups'))
  end

  def active_inbox_agent_bot(inbox)
    return unless inbox.agent_bot_inbox&.active?

    inbox.agent_bot
  end

  def process_message_event(method_name, agent_bot, message, _event)
    # Only webhook bots are supported
    payload = message.webhook_data.merge(event: method_name)
    process_webhook_bot_event(agent_bot, payload)
  end

  def process_webhook_bot_event(agent_bot, payload)
    return if agent_bot.outgoing_url.blank?

    AgentBots::WebhookJob.perform_later(agent_bot.outgoing_url, payload, :agent_bot_webhook,
                                        secret: agent_bot.secret, delivery_id: SecureRandom.uuid)
  end
end
