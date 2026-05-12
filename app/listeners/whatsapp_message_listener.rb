class WhatsappMessageListener < BaseListener
  def message_updated(event)
    message, account = extract_message_and_account(event)
    return unless message.inbox.channel_type == 'Channel::Whatsapp'
    
    # We only care about deletion for now
    return unless message.content_attributes['deleted'] == true
    
    # Check if deletion just happened
    # previous_changes structure: { 'content_attributes' => [old_val, new_val] }
    previous_changes = event.data[:previous_changes]
    return unless previous_changes&.dig('content_attributes')
    
    old_attributes = previous_changes['content_attributes'][0] || {}
    new_attributes = previous_changes['content_attributes'][1] || {}
    
    return if old_attributes['deleted'] == true # Already deleted
    return unless new_attributes['deleted'] == true
    
    # Only for specific providers that support it
    return unless %w[evolution_go].include?(message.inbox.channel.provider)
    
    Whatsapp::DeleteMessageJob.perform_later(message.id)
  end
end
