# Runs the question that precedes the CSAT survey: a message with up to three quick replies, one
# reply message per button, and the survey itself behind the button the admin marked as positive.
# Every answer is recorded as an activity message so the report of what contacts answered survives
# even for the branches that never reach the survey.
class CsatFlowService
  # The classic Evolution provider sends plain text and attachments only, so a question with buttons
  # would reach the contact as a bare sentence. The flow stays off there and the survey goes as usual.
  UNSUPPORTED_WHATSAPP_PROVIDERS = %w[evolution].freeze
  # Evolution GO has no notion of approved templates: there a question is always composed here.
  PROVIDERS_WITHOUT_TEMPLATES = %w[evolution_go].freeze

  pattr_initialize [:conversation!]

  # WhatsApp delivers a tapped quick reply as plain text, so buttons are matched by their label.
  def self.normalize(text)
    I18n.transliterate(text.to_s).downcase.strip.squeeze(' ')
  end

  def self.supported?(inbox)
    return UNSUPPORTED_WHATSAPP_PROVIDERS.exclude?(inbox.channel.provider) if inbox.whatsapp?

    inbox.web_widget?
  end

  # Buttons composed here reach the contact inside the messaging window on every supported channel.
  # An approved template is what carries them outside of it, so it is offered where it exists.
  def self.templates_available?(inbox)
    inbox.whatsapp? && PROVIDERS_WITHOUT_TEMPLATES.exclude?(inbox.channel.provider)
  end

  # A node goes out as a template when one was picked for it, and is composed here otherwise.
  def self.template_node?(node)
    node&.dig('template', 'name').present?
  end

  # Evolution GO rejects an interactive message with no header; the official API has no header on
  # button messages at all and ignores it.
  def self.header_required?(inbox)
    inbox.whatsapp? && inbox.channel.provider == 'evolution_go'
  end

  # Call-to-action buttons ride on Evolution GO's own endpoint and, on the widget, on a link item.
  # The official API would drop them without a word, so they are refused there instead.
  def self.action_buttons_available?(inbox)
    inbox.web_widget? || (inbox.whatsapp? && inbox.channel.provider == 'evolution_go')
  end

  def enabled?
    flow['enabled'].present? && flow['buttons'].present? && self.class.supported?(inbox)
  end

  # Returns false when there is no flow to run, so CsatSurveyService falls back to the survey.
  def start
    return false unless enabled?
    # A question composed here only reaches the contact inside the messaging window; one sent as an
    # approved template is exactly how that window is bypassed. The widget and Evolution GO have no
    # window at all, so only the official WhatsApp providers can be held back here.
    return false unless self.class.template_node?(flow) || conversation.can_reply?

    message = send_node(flow, stage: 'question')
    return false if message.blank?

    conversation.store_csat_flow_state!(stage: 'question', message: message, silent: silent_titles(flow['buttons']))
    true
  end

  # Anything the contact sends that is not one of the parked buttons ends the flow: they moved on,
  # the conversation reopened and the agent is back in charge.
  def handle_reply(answer)
    return if answer.blank?

    state = conversation.csat_flow_state
    return if state.blank? || state['answered_at'].present?

    index = matching_button_index(state, answer)
    return conversation.close_csat_flow_state! if index.blank?

    button = stage_buttons(state)[index]
    conversation.close_csat_flow_state!
    record_answer(button, state)
    deliver_reply(button['reply'], index, state) if state['stage'] == 'question'
  end

  private

  delegate :inbox, to: :conversation

  def flow
    inbox.csat_config&.dig('flow') || {}
  end

  # The buttons are read back from the inbox instead of the parked state, so editing the flow never
  # leaves a conversation answering against a definition that no longer exists.
  def stage_buttons(state)
    return Array(flow['buttons']) if state['stage'] == 'question'

    Array(flow.dig('buttons', state['button_index'].to_i, 'reply', 'buttons'))
  end

  def matching_button_index(state, answer)
    normalized = self.class.normalize(answer)
    return if normalized.blank?

    stage_buttons(state).index { |button| self.class.normalize(button['title']) == normalized }
  end

  # Buttons that reopen the conversation are left out: the guard in Message only silences the ones
  # listed here, so a contact asking for help still gets the conversation back on the agent's queue.
  def silent_titles(buttons)
    Array(buttons).reject { |button| button['reopen'] }.map { |button| self.class.normalize(button['title']) }
  end

  def record_answer(button, state)
    conversation.add_labels([button['label']]) if button['label'].present?
    create_activity_message(activity_content(button, state))
  end

  def activity_content(button, state)
    return I18n.t('conversations.activity.csat.flow_reply', answer: button['title']) unless state['stage'] == 'question'

    I18n.t(
      'conversations.activity.csat.flow_answer',
      answer: button['title'],
      sentiment: I18n.t("conversations.activity.csat.sentiment.#{button['sentiment']}")
    )
  end

  def create_activity_message(content)
    ::Conversations::ActivityMessageJob.perform_later(
      conversation,
      { account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity, content: content }
    )
  end

  def deliver_reply(reply, button_index, state)
    return if reply.blank?
    return ::CsatSurveyService.new(conversation: conversation, skip_flow: true).perform if reply['type'] == 'csat_survey'

    message = send_node(reply, stage: 'reply')
    return if message.blank? || reply['button_type'] != 'quick_reply'

    # The question's own buttons stay silenced: they are still on screen and still tappable.
    conversation.store_csat_flow_state!(
      stage: 'reply', message: message, button_index: button_index,
      silent: state['silent'].to_a | silent_titles(reply['buttons'])
    )
  end

  def send_node(node, stage:)
    ::MessageTemplates::Template::CsatFlowNode.new(conversation: conversation, node: node, stage: stage).perform
  end
end
