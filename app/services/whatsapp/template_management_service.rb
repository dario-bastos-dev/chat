class Whatsapp::TemplateManagementService
  CATEGORIES = %w[MARKETING UTILITY AUTHENTICATION].freeze
  BUTTON_TYPES = %w[QUICK_REPLY URL PHONE_NUMBER COPY_CODE ORDER_DETAILS].freeze
  # Meta fixes the label on these, so they carry no text of their own.
  LABELLESS_BUTTON_TYPES = %w[COPY_CODE].freeze
  # A payment button turns the whole template into an order details one, which Meta flags at the top
  # level rather than on the component.
  ORDER_DETAILS_FORMAT = 'ORDER_DETAILS'.freeze
  COPY_CODE_MAX_LENGTH = 15
  MEDIA_FORMATS = %w[IMAGE VIDEO DOCUMENT].freeze
  NAME_FORMAT = /\A[a-z0-9_]{1,512}\z/
  # Placeholders are either all numeric ({{1}}) or all named ({{order_id}});
  # Meta rejects a template that mixes the two styles.
  VARIABLE_PATTERN = /\{\{\s*([A-Za-z0-9_]+)\s*\}\}/
  NAMED_VARIABLE_FORMAT = /\A[a-z][a-z0-9]*(?:_[a-z0-9]+)*\z/
  POSITIONAL_FORMAT = 'POSITIONAL'.freeze
  NAMED_FORMAT = 'NAMED'.freeze
  DEFAULT_LANGUAGE = 'en'.freeze
  BODY_MAX_LENGTH = 1024
  HEADER_MAX_LENGTH = 60
  FOOTER_MAX_LENGTH = 60
  BUTTON_TEXT_MAX_LENGTH = 25

  class ValidationError < StandardError; end

  def initialize(whatsapp_channel)
    @whatsapp_channel = whatsapp_channel
  end

  def create_template(params)
    request_body = build_request_body(params)
    response = HTTParty.post("#{business_account_path}/message_templates", headers: api_headers, body: request_body.to_json)
    process_creation_response(response, request_body)
  rescue ValidationError => e
    { success: false, error: e.message }
  end

  # Meta edits a template by id, not by name, and only the components can change.
  def update_template(template_id, params)
    request_body = build_update_body(params)
    response = HTTParty.post("#{api_base_path}/#{api_version}/#{template_id}", headers: api_headers, body: request_body.to_json)
    process_update_response(response)
  rescue ValidationError => e
    { success: false, error: e.message }
  end

  def delete_template(name)
    response = HTTParty.delete("#{business_account_path}/message_templates?name=#{name}", headers: api_headers)
    { success: response.success?, response_body: response.body }
  end

  def template_status(name)
    response = HTTParty.get("#{business_account_path}/message_templates?name=#{name}", headers: api_headers)
    return { success: false, error: 'Template not found' } unless response.success? && response['data'].present?

    template = response['data'].first
    { success: true, template: template.slice('id', 'name', 'status', 'language', 'category') }
  end

  private

  def build_request_body(params)
    validate!(params)

    body = {
      name: params[:name],
      language: params[:language].presence || DEFAULT_LANGUAGE,
      category: params[:category],
      parameter_format: parameter_format(params),
      components: build_components(params)
    }
    body[:display_format] = ORDER_DETAILS_FORMAT if order_details_template?(params)
    body
  end

  def order_details_template?(params)
    Array(params[:buttons]).any? { |button| button[:type] == 'ORDER_DETAILS' }
  end

  def build_update_body(params)
    validate_content!(params)

    {
      parameter_format: parameter_format(params),
      components: build_components(params)
    }
  end

  def process_update_response(response)
    return { success: true } if response.success?

    Rails.logger.error "WhatsApp template update failed: #{response.code} - #{response.body}"
    { success: false, error: 'Template update failed', response_body: response.body }
  end

  def extract_variables(text)
    text.to_s.scan(VARIABLE_PATTERN).flatten.uniq
  end

  def named_variables?(variables)
    variables.any? { |variable| !variable.match?(/\A\d+\z/) }
  end

  # The format is derived from what the author typed, so the caller never has to
  # declare it. Header and body must agree, which validate_variable_styles! enforces.
  def parameter_format(params)
    variables = extract_variables(params.dig(:body, :text)) + extract_variables(params.dig(:header, :text))
    named_variables?(variables) ? NAMED_FORMAT : POSITIONAL_FORMAT
  end

  def build_components(params)
    [
      header_component(params[:header]),
      body_component(params[:body]),
      footer_component(params[:footer]),
      buttons_component(params[:buttons])
    ].compact
  end

  def header_component(header)
    return if header.blank?

    format = header_format(header)
    return media_header_component(header, format) if MEDIA_FORMATS.include?(format)
    return if header[:text].blank?

    component = { type: 'HEADER', format: 'TEXT', text: header[:text] }
    component[:example] = header_example(header) if header[:example].present?
    component
  end

  def header_example(header)
    variables = extract_variables(header[:text])
    return { header_text: Array(header[:example]) } unless named_variables?(variables)

    { header_text_named_params: named_params(variables, header[:example]) }
  end

  def named_params(variables, examples)
    variables.each_with_index.map do |variable, index|
      { param_name: variable, example: Array(examples)[index] }
    end
  end

  def media_header_component(header, format)
    { type: 'HEADER', format: format, example: { header_handle: [header[:media_handle]] } }
  end

  def header_format(header)
    header[:format].presence&.upcase || 'TEXT'
  end

  def body_component(body)
    component = { type: 'BODY', text: body[:text] }
    component[:example] = body_example(body) if body[:example].present?
    component
  end

  def body_example(body)
    variables = extract_variables(body[:text])
    return { body_text_named_params: named_params(variables, body[:example]) } if named_variables?(variables)

    # Positional examples go as an array of sample sets, one set per variable group.
    { body_text: [Array(body[:example])] }
  end

  def footer_component(footer)
    return if footer.blank? || footer[:text].blank?

    { type: 'FOOTER', text: footer[:text] }
  end

  def buttons_component(buttons)
    return if buttons.blank?

    { type: 'BUTTONS', buttons: buttons.map { |button| build_button(button) } }
  end

  def build_button(button)
    case button[:type]
    when 'URL'
      payload = { type: 'URL', text: button[:text], url: button[:url] }
      payload[:example] = Array(button[:example]) if button[:example].present?
      payload
    when 'PHONE_NUMBER'
      { type: 'PHONE_NUMBER', text: button[:text], phone_number: button[:phone_number] }
    when 'COPY_CODE'
      # No label: Meta renders its own. Sent as `code` because `example` is reserved for the URL
      # button's array of samples, and strong params cannot permit one key as both scalar and array.
      { type: 'COPY_CODE', example: button[:code] }
    when 'ORDER_DETAILS'
      { type: 'ORDER_DETAILS', text: button[:text] }
    else
      { type: 'QUICK_REPLY', text: button[:text] }
    end
  end

  def validate!(params)
    raise ValidationError, 'Name must contain only lowercase letters, numbers and underscores' unless params[:name].to_s.match?(NAME_FORMAT)
    raise ValidationError, "Category must be one of #{CATEGORIES.join(', ')}" unless CATEGORIES.include?(params[:category])

    validate_content!(params)
  end

  # Name, language and category are immutable on an edit, so only the content
  # rules are shared between create and update.
  def validate_content!(params)
    validate_variable_styles!(params)
    validate_body!(params[:body])
    validate_header!(params[:header])
    validate_footer!(params[:footer])
    validate_buttons!(params[:buttons])
  end

  def validate_body!(body)
    text = body.is_a?(Hash) ? body[:text].to_s : ''
    raise ValidationError, 'Body text is required' if text.blank?
    raise ValidationError, "Body text must be under #{BODY_MAX_LENGTH} characters" if text.length > BODY_MAX_LENGTH

    validate_variables!(text, Array(body[:example]), 'Body')
  end

  def validate_header!(header)
    return if header.blank?

    format = header_format(header)
    if MEDIA_FORMATS.include?(format)
      raise ValidationError, "#{format} headers require an uploaded file" if header[:media_handle].blank?

      return
    end

    return if header[:text].blank?

    text = header[:text].to_s
    raise ValidationError, "Header text must be under #{HEADER_MAX_LENGTH} characters" if text.length > HEADER_MAX_LENGTH
    raise ValidationError, 'Header supports at most one variable' if variable_count(text) > 1

    validate_variables!(text, Array(header[:example]), 'Header')
  end

  def validate_footer!(footer)
    return if footer.blank? || footer[:text].blank?

    text = footer[:text].to_s
    raise ValidationError, "Footer text must be under #{FOOTER_MAX_LENGTH} characters" if text.length > FOOTER_MAX_LENGTH
    raise ValidationError, 'Footer cannot contain variables' if variable_count(text).positive?
  end

  def validate_buttons!(buttons)
    return if buttons.blank?

    raise ValidationError, 'A template supports at most 10 buttons' if buttons.length > 10

    types = buttons.pluck(:type)
    raise ValidationError, "Button type must be one of #{BUTTON_TYPES.join(', ')}" unless types.all? { |type| BUTTON_TYPES.include?(type) }
    raise ValidationError, 'Buttons require a label' if labelled_buttons(buttons).any? { |button| button[:text].blank? }
    raise ValidationError, "Button labels must be under #{BUTTON_TEXT_MAX_LENGTH} characters" if button_label_too_long?(buttons)
    raise ValidationError, 'A template supports at most 2 URL buttons' if types.count('URL') > 2
    raise ValidationError, 'A template supports at most 1 phone number button' if types.count('PHONE_NUMBER') > 1
    raise ValidationError, 'A template supports at most 1 copy code button' if types.count('COPY_CODE') > 1

    validate_url_buttons!(buttons.select { |button| button[:type] == 'URL' })
    validate_copy_code_buttons!(buttons.select { |button| button[:type] == 'COPY_CODE' })
    validate_order_details_buttons!(buttons, types)
  end

  def labelled_buttons(buttons)
    buttons.reject { |button| LABELLESS_BUTTON_TYPES.include?(button[:type]) }
  end

  def validate_copy_code_buttons!(buttons)
    buttons.each do |button|
      code = button[:code].to_s
      raise ValidationError, 'Copy code buttons require an example code' if code.blank?
      raise ValidationError, "Copy code examples must be #{COPY_CODE_MAX_LENGTH} characters or shorter" if code.length > COPY_CODE_MAX_LENGTH
    end
  end

  # The payment button replaces the whole call to action area, so Meta rejects it next to any other
  # button type.
  def validate_order_details_buttons!(buttons, types)
    count = types.count('ORDER_DETAILS')
    return if count.zero?

    raise ValidationError, 'A template supports at most 1 payment button' if count > 1
    raise ValidationError, 'A payment button cannot be combined with other buttons' if buttons.length > 1
  end

  def button_label_too_long?(buttons)
    labelled_buttons(buttons).any? { |button| button[:text].to_s.length > BUTTON_TEXT_MAX_LENGTH }
  end

  # Meta only accepts a single variable per URL button and it must be the last
  # thing in the URL, so `https://x.com/{{1}}/details` is rejected upstream.
  def validate_url_buttons!(buttons)
    buttons.each do |button|
      url = button[:url].to_s
      raise ValidationError, 'URL buttons require a URL' if url.blank?

      variables = url.scan(/\{\{\d+\}\}/)
      next if variables.empty?

      raise ValidationError, 'URL buttons support at most one variable' if variables.size > 1
      raise ValidationError, 'The URL button variable must be at the end of the URL' unless url.end_with?(variables.first)
    end
  end

  # Meta rejects templates whose placeholders are not sequential from {{1}}, whose
  # named placeholders are malformed, or whose sample values do not match the
  # placeholder count, so we catch all of it before the request.
  def validate_variables!(text, examples, label)
    variables = extract_variables(text)
    return if variables.empty? && examples.empty?

    if named_variables?(variables)
      validate_named_variables!(variables, label)
    else
      validate_positional_variables!(variables, label)
    end

    raise ValidationError, "#{label} requires one sample value per variable" if examples.size != variables.size
  end

  def validate_positional_variables!(variables, label)
    numbers = variables.map(&:to_i).sort
    return if numbers == (1..numbers.size).to_a

    raise ValidationError, "#{label} variables must be numbered sequentially starting at 1"
  end

  def validate_named_variables!(variables, label)
    return if variables.all? { |variable| variable.match?(NAMED_VARIABLE_FORMAT) }

    raise ValidationError,
          "#{label} variable names must use lowercase letters, numbers and single underscores between words"
  end

  # A template is either fully positional or fully named; Meta rejects the mix.
  def validate_variable_styles!(params)
    header_variables = extract_variables(params.dig(:header, :text))
    body_variables = extract_variables(params.dig(:body, :text))
    return if header_variables.empty? || body_variables.empty?
    return if named_variables?(header_variables) == named_variables?(body_variables)

    raise ValidationError, 'Header and body must both use either numbered or named variables, not a mix'
  end

  def variable_count(text)
    extract_variables(text).size
  end

  def process_creation_response(response, request_body)
    unless response.success?
      Rails.logger.error "WhatsApp template creation failed: #{response.code} - #{response.body}"
      return { success: false, error: 'Template creation failed', response_body: response.body }
    end

    {
      success: true,
      template_id: response['id'],
      template_name: request_body[:name],
      language: request_body[:language],
      category: response['category'] || request_body[:category],
      status: response['status'] || 'PENDING'
    }
  end

  def business_account_path
    "#{api_base_path}/#{api_version}/#{@whatsapp_channel.provider_config['business_account_id']}"
  end

  def api_headers
    {
      'Authorization' => "Bearer #{@whatsapp_channel.provider_config['api_key']}",
      'Content-Type' => 'application/json'
    }
  end

  def api_version
    GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')
  end

  def api_base_path
    ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
  end
end
