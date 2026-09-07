class CsatSurveyListener < BaseListener
  def conversation_status_changed(event)
    conversation = extract_conversation_and_account(event)[0]

    return unless conversation.resolved?

    CsatSurveyService.new(conversation: conversation).perform
  end

  # WhatsApp delivers a tapped quick reply as an incoming message. An agent stepping back into the
  # conversation ends the flow instead: the question parked on it is stale from then on.
  def message_created(event)
    message = extract_message_and_account(event)[0]
    return if message.private?
    return message.conversation.clear_csat_flow_state! if message.outgoing? && message.sender_type == 'User'
    return unless message.incoming?

    CsatFlowService.new(conversation: message.conversation).handle_reply(message.content)
  end

  def message_updated(event)
    message = extract_message_and_account(event)[0]
    return CsatSurveys::ResponseBuilder.new(message: message).perform if message.input_csat?
    return unless message.content_type == 'input_select'

    # The widget answers in place instead of sending a message of its own. Every other update of the
    # same message - recording the source id after the send, for one - carries no answer at all.
    answer = Array(message.submitted_values).first&.dig('value')
    return if answer.blank?

    CsatFlowService.new(conversation: message.conversation).handle_reply(answer)
  end
end
