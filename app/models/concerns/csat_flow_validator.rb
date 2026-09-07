# The CSAT flow turns the survey into a question with up to three quick replies, one per sentiment,
# and an optional reply message behind each of them. Reply messages are leaves: their own buttons
# never branch again, so a contact is never more than two taps away from the end of the flow.
class CsatFlowValidator < ActiveModel::Validator
  SENTIMENTS = %w[positive negative neutral].freeze
  REPLY_TYPES = %w[message csat_survey].freeze
  BUTTON_TYPES = %w[quick_reply action].freeze
  ACTION_TYPES = %w[url call].freeze
  MAX_BUTTONS = 3
  MAX_TITLE_LENGTH = 20

  def validate(record)
    flow = record.csat_config&.dig('flow')
    return if flow.blank? || !flow['enabled']
    # A channel that cannot run the flow should not block unrelated inbox settings from being saved.
    return unless CsatFlowService.supported?(record)

    error(record, 'flow templates are not available on this inbox') if template_mode?(record) && !CsatFlowService.templates_available?(record)

    validate_node!(record, flow, 'question', has_buttons: true)
    validate_buttons!(record, flow['buttons'])
  end

  private

  def error(record, message)
    record.errors.add(:csat_config, message)
  end

  # Shared between the question and the reply messages: both carry a body, optionally a template and
  # optionally their own buttons.
  def validate_node!(record, node, label, has_buttons:)
    error(record, "#{label} message is required") if node['message'].blank?
    error(record, "#{label} requires an approved template") if template_mode?(record) && node.dig('template', 'name').blank?
    error(record, "#{label} requires a header") if header_required?(record, node, has_buttons) && node['header'].blank?
  end

  # Only Evolution GO needs one, and only for a message it composes itself.
  def header_required?(record, node, has_buttons)
    has_buttons && CsatFlowService.header_required?(record) && !CsatFlowService.template_node?(node)
  end

  # The admin picks per inbox whether the flow is composed here or carried by approved templates.
  def template_mode?(record)
    record.csat_config.dig('flow', 'mode') == 'template'
  end

  def validate_buttons!(record, buttons)
    return error(record, 'flow requires at least one button') if buttons.blank?
    return error(record, "flow cannot exceed #{MAX_BUTTONS} buttons") if buttons.size > MAX_BUTTONS
    return error(record, 'flow buttons should be hashes') unless buttons.all?(Hash)

    validate_titles!(record, buttons)
    validate_sentiments!(record, buttons)
    buttons.each { |button| validate_reply!(record, button['reply']) }
  end

  # An answer is matched against the label the contact tapped, so two buttons cannot share a title.
  def validate_titles!(record, buttons)
    titles = buttons.map { |button| button['title'].to_s.strip }
    return error(record, 'flow button titles are required') if titles.any?(&:blank?)
    return error(record, "flow button titles cannot exceed #{MAX_TITLE_LENGTH} characters") if titles.any? { |t| t.length > MAX_TITLE_LENGTH }

    error(record, 'flow button titles should be unique') if titles.map(&:downcase).uniq.size != titles.size
  end

  def validate_sentiments!(record, buttons)
    sentiments = buttons.map { |button| button['sentiment'] }
    return error(record, "flow sentiments should be one of #{SENTIMENTS.join(', ')}") unless sentiments.all? { |s| SENTIMENTS.include?(s) }

    error(record, 'flow buttons should not repeat a sentiment') if sentiments.uniq.size != sentiments.size
  end

  def validate_reply!(record, reply)
    return if reply.blank?
    return error(record, "flow reply type should be one of #{REPLY_TYPES.join(', ')}") unless REPLY_TYPES.include?(reply['type'])
    return unless reply['type'] == 'message'

    validate_node!(record, reply, 'flow reply', has_buttons: reply['buttons'].present?)
    validate_reply_buttons!(record, reply)
  end

  def validate_reply_buttons!(record, reply)
    buttons = reply['buttons']
    return if buttons.blank?
    return error(record, "flow reply buttons should be #{BUTTON_TYPES.join(' or ')}") unless BUTTON_TYPES.include?(reply['button_type'])
    return error(record, "flow reply cannot exceed #{MAX_BUTTONS} buttons") if buttons.size > MAX_BUTTONS

    return validate_titles!(record, buttons) unless reply['button_type'] == 'action'
    return error(record, 'action buttons are not available on this inbox') unless CsatFlowService.action_buttons_available?(record)

    validate_action_buttons!(record, buttons)
  end

  def validate_action_buttons!(record, buttons)
    return error(record, "flow action buttons should be #{ACTION_TYPES.join(' or ')}") unless buttons.all? { |b| ACTION_TYPES.include?(b['type']) }
    return error(record, 'flow action buttons require a text') if buttons.any? { |b| b['text'].blank? }

    error(record, 'flow action buttons require a destination') if buttons.any? { |b| destination(b).blank? }
  end

  def destination(button)
    button['type'] == 'url' ? button['url'] : button['phone_number']
  end
end
