# Builds one message of the CSAT flow: the question that opens it or the reply behind a button.
# A node that carries an approved template goes out as plain text with `template_params`, since the
# template already holds the body and the buttons; every other node is composed here.
class MessageTemplates::Template::CsatFlowNode
  pattr_initialize [:conversation!, :node!, :stage!]

  def perform
    conversation.messages.create!(message_params)
  end

  private

  delegate :inbox, to: :conversation

  def message_params
    params = {
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :template,
      content: node['message'],
      content_type: content_type,
      content_attributes: content_attributes
    }
    return params.merge(additional_attributes: { template_params: node['template'] }) if template_mode?

    params
  end

  def template_mode?
    CsatFlowService.template_node?(node)
  end

  def action_buttons?
    !template_mode? && node['button_type'] == 'action' && node['buttons'].present?
  end

  def content_type
    return :text if template_mode? || cta_message? || items.blank?

    :input_select
  end

  # Call-to-action buttons have no equivalent outside Evolution GO, so they travel on their own key
  # of a plain text message the way the rich message composer sends them.
  def cta_message?
    action_buttons? && !inbox.web_widget?
  end

  def content_attributes
    attributes = { csat_flow: stage }
    return attributes if template_mode?
    return attributes.merge(whatsapp_buttons: cta_attributes) if cta_message?

    attributes.merge(items: items.presence, title: node['header'].presence, footer: node['footer'].presence).compact
  end

  # Quick replies and, on the widget, action buttons: there a link button is an item carrying a uri,
  # the same shape the greeting message uses.
  def items
    Array(node['buttons']).filter_map do |button|
      next { title: button['title'], value: button['title'] } unless action_buttons?
      next if button['type'] != 'url'

      { title: button['text'], value: button['text'], uri: button['url'] }
    end
  end

  def cta_attributes
    {
      title: node['header'],
      footer: node['footer'].presence,
      buttons: Array(node['buttons'])
    }.compact
  end
end
