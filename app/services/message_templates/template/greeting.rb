class MessageTemplates::Template::Greeting
  pattr_initialize [:conversation!]

  def perform
    ActiveRecord::Base.transaction do
      conversation.messages.create!(greeting_message_params)
    end
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: conversation.account).capture_exception
    true
  end

  private

  delegate :contact, :account, to: :conversation

  def greeting_message_params
    inbox = @conversation.inbox
    params = {
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :template,
      content: inbox&.greeting_message
    }

    return params if inbox&.greeting_items.blank?

    params.merge(content_type: :input_select, content_attributes: { items: greeting_items(inbox) })
  end

  def greeting_items(inbox)
    inbox.greeting_items.map do |item|
      { title: item['title'], value: item['value'].presence || item['title'], uri: item['uri'].presence }.compact
    end
  end
end
