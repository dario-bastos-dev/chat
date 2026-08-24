class Whatsapp::TemplateProcessorService
  pattr_initialize [:channel!, :template_params, :message]

  def call
    return [nil, nil, nil, nil] if template_params.blank?

    process_template_with_params
  end

  private

  def process_template_with_params
    [
      template_params['name'],
      template_params['namespace'],
      template_params['language'],
      processed_templates_params
    ]
  end

  def find_template
    channel.message_templates.find do |t|
      t['name'] == template_params['name'] &&
        t['language']&.downcase == template_params['language']&.downcase &&
        t['status']&.downcase == 'approved'
    end
  end

  def processed_templates_params
    template = find_template
    return if template.blank?

    # Convert legacy format to enhanced format before processing
    converter = Whatsapp::TemplateParameterConverterService.new(template_params, template)
    normalized_params = converter.normalize_to_enhanced

    process_enhanced_template_params(template, normalized_params['processed_params'])
  end

  def process_enhanced_template_params(template, processed_params = nil)
    processed_params ||= template_params['processed_params']
    components = []

    components.concat(process_header_components(processed_params, template))
    components.concat(process_body_components(processed_params, template))
    components.concat(process_footer_components(processed_params))
    components.concat(process_button_components(processed_params))
    components.concat(process_order_details_components(processed_params))

    @template_params = components
  end

  # A payment template is not sent like the others: instead of text parameters, the whole order rides
  # in the button component as an action. Meta rejects the send when any required piece is missing, so
  # an incomplete order produces no component at all rather than a malformed one.
  # https://developers.facebook.com/documentation/business-messaging/whatsapp/payments/payments-br/orderdetailstemplate/
  def process_order_details_components(processed_params)
    order = processed_params['order_details']
    return [] if order.blank?

    settings = payment_settings(order)
    return [] if settings.blank? || order['reference_id'].blank?

    [{
      type: 'button',
      sub_type: 'order_details',
      index: 0,
      parameters: [{ type: 'action', action: { order_details: order_details_payload(order, settings) } }]
    }]
  end

  def order_details_payload(order, settings)
    {
      reference_id: order['reference_id'],
      type: order['goods_type'].presence || 'digital-goods',
      payment_type: 'br',
      payment_settings: settings,
      currency: 'BRL',
      total_amount: { value: amount_in_cents(order['total_amount']), offset: 100 }
    }
  end

  # Meta takes the amount as an integer in the currency's smallest unit, paired with offset 100 for
  # BRL.
  def amount_in_cents(amount)
    (normalize_decimal(amount.to_s) * 100).round
  end

  # Accepts "129,90" and "129.90" as well as "1.234,56" and "1,234.56": whichever separator comes
  # last is the decimal one and the other is grouping. Stripping dots blindly would read "129.90" as
  # 12990 and charge the customer a hundred times the intended amount.
  def normalize_decimal(value)
    digits = value.gsub(/[^\d.,]/, '')
    return 0.to_d if digits.blank?
    return digits.tr(',', '.').to_d unless digits.include?('.') && digits.include?(',')

    if digits.rindex(',') > digits.rindex('.')
      digits.delete('.').tr(',', '.').to_d
    else
      digits.delete(',').to_d
    end
  end

  def payment_settings(order)
    case order['payment_type']
    when 'pix_dynamic_code' then pix_settings(order)
    when 'boleto' then boleto_settings(order)
    when 'payment_link' then payment_link_settings(order)
    else []
    end
  end

  def pix_settings(order)
    required = order.values_at('pix_code', 'pix_merchant_name', 'pix_key', 'pix_key_type')
    return [] if required.any?(&:blank?)

    [{
      type: 'pix_dynamic_code',
      pix_dynamic_code: {
        code: order['pix_code'],
        merchant_name: order['pix_merchant_name'],
        key: order['pix_key'],
        key_type: order['pix_key_type']
      }
    }]
  end

  def boleto_settings(order)
    return [] if order['boleto_digitable_line'].blank?

    [{ type: 'boleto', boleto: { digitable_line: order['boleto_digitable_line'] } }]
  end

  def payment_link_settings(order)
    return [] if order['payment_link_uri'].blank?

    [{ type: 'payment_link', payment_link: { uri: order['payment_link_uri'] } }]
  end

  def process_header_components(processed_params, template)
    header_data = apply_stored_media(processed_params['header'] || {}, template)
    return [] if header_data.blank?

    header_params = build_header_params(header_data, template)
    header_params.present? ? [{ type: 'header', parameters: header_params }] : []
  end

  # Templates created through Chatwoot keep a copy of their media. Meta requires it on every send but
  # only stores the approval sample, behind a signed URL that expires, so the stored copy is what the
  # send points Meta at.
  #
  # That URL is signed and short-lived, so it is resolved here instead of being taken from the caller:
  # a campaign or automation persists the parameters it was built with and would replay a link that
  # already expired, which Meta answers with #131053. A URL the user typed in place of the stored
  # media is left untouched.
  def apply_stored_media(header_data, template)
    media_format = media_header_format(template)
    return header_data if media_format.blank?

    stored = WhatsappTemplateMedia.find_by(account_id: channel.account_id, template_name: template['name'], language: template['language'])
    stored_url = stored&.url
    return header_data if stored_url.blank? || external_media?(header_data['media_url'], stored_url)

    header_data.merge('media_url' => stored_url, 'media_type' => header_data['media_type'].presence || media_format)
  end

  # Media the user pointed at by hand, which lives on someone else's host and is theirs to keep. The
  # host and not the file: the stored copy can be replaced when the template is edited, and a caller
  # holding the previous URL still means "the media this template carries".
  def external_media?(media_url, stored_url)
    return false if media_url.blank?

    URI.parse(media_url.to_s).host != URI.parse(stored_url).host
  rescue URI::InvalidURIError
    true
  end

  def media_header_format(template)
    header_component = template['components']&.find { |component| component['type'] == 'HEADER' }
    format = header_component&.dig('format').to_s.downcase

    %w[image video document].include?(format) ? format : nil
  end

  def build_header_params(header_data, template)
    header_component = template['components']&.find { |component| component['type'] == 'HEADER' }
    return build_text_header_params(header_data, template) if header_component&.dig('format') == 'TEXT'

    build_media_header_params(header_data)
  end

  def build_text_header_params(header_data, template)
    header_data.filter_map do |key, value|
      build_text_parameter(key, value, template) if value.present?
    end
  end

  def build_media_header_params(header_data)
    return [] if header_data['media_url'].blank? || header_data['media_type'].blank?

    media_param = parameter_builder.build_media_parameter(header_data['media_url'], header_data['media_type'], header_data['media_name'])
    media_param ? [media_param] : []
  end

  def process_body_components(processed_params, template)
    return [] if processed_params['body'].blank?

    body_parameters = processed_params['body']
    body_parameters = body_parameters.sort_by { |key, _value| key.to_i } unless template['parameter_format'] == 'NAMED'

    body_params = body_parameters.filter_map do |key, value|
      next if value.blank?

      build_text_parameter(key, value, template)
    end

    body_params.present? ? [{ type: 'body', parameters: body_params }] : []
  end

  def build_text_parameter(key, value, template)
    return parameter_builder.build_named_parameter(key, value) if template['parameter_format'] == 'NAMED'

    parameter_builder.build_parameter(value)
  end

  def process_footer_components(processed_params)
    return [] if processed_params['footer'].blank?

    footer_params = processed_params['footer'].filter_map do |_, value|
      next if value.blank?

      parameter_builder.build_parameter(value)
    end

    footer_params.present? ? [{ type: 'footer', parameters: footer_params }] : []
  end

  def process_button_components(processed_params)
    return [] if processed_params['buttons'].blank?

    button_params = processed_params['buttons'].filter_map.with_index do |button, index|
      next if button.blank?

      if button['type'] == 'url' || button['parameter'].present?
        {
          type: 'button',
          sub_type: button['type'] || 'url',
          index: index,
          parameters: [parameter_builder.build_button_parameter(button)]
        }
      end
    end

    button_params.compact
  end

  def parameter_builder
    @parameter_builder ||= Whatsapp::PopulateTemplateParametersService.new
  end
end
