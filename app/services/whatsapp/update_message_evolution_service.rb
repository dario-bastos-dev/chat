class Whatsapp::UpdateMessageEvolutionService
  pattr_initialize [:inbox!, :params!]

  def perform
    @normalized_params = normalize_params(params)
    
    # Early return if not an edit event
    return unless edited_message_data.present?

    # Find the original message by source_id
    message = Message.find_by(source_id: key_id)
    return if message.nil?

    # Update with edit indicator
    message.update!(content: "#{new_text_content}\n\n_(Editada)_")
    
    Rails.logger.info "[EVOLUTION MSG] Updated message #{message.id}"
  rescue StandardError => e
    Rails.logger.error "[EVOLUTION MSG UPDATE] Error: #{e.message}"
  end

  private

  def normalize_params(p)
    JSON.parse(p.to_json)
  rescue JSON::GeneratorError, JSON::ParserError
    p.to_h.transform_keys(&:to_s)
  end

  def data_params
    @data_params ||= @normalized_params['data'] || {}
  end

  def key_id
    @key_id ||= data_params['keyId'] || data_params.dig('key', 'id')
  end

  def message_object
    @message_object ||= data_params['message'] || {}
  end

  def edited_message_data
    @edited_message_data ||= message_object.dig('editedMessage', 'message')
  end

  def new_text_content
    return '' unless edited_message_data

    edited_message_data['conversation'] || 
    edited_message_data.dig('extendedTextMessage', 'text') ||
    edited_message_data.dig('protocolMessage', 'editedMessage', 'conversation') ||
    ''
  end
end
