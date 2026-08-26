class Instagram::BaseSendService < Base::SendOnChannelService
  pattr_initialize [:message!]

  private

  delegate :additional_attributes, to: :contact

  def perform_reply
    send_attachments if message.attachments.present?
    send_content if message.content.present?
  rescue StandardError => e
    handle_error(e)
  end

  def send_attachments
    message.attachments.each do |attachment|
      send_message(attachment_message_params(attachment))
    end
  end

  def send_content
    send_message(message_params)
  end

  def handle_error(error)
    ChatwootExceptionTracker.new(error, account: message.account, user: message.sender).capture_exception
  end

  def message_params
    params = {
      recipient: { id: contact.get_source_id(inbox.id) },
      message: message_payload
    }

    merge_human_agent_tag(params)
  end

  # Items with a `uri` need a button template, plain choices are cheaper to render as quick replies.
  def message_payload
    return { text: message.outgoing_content } if select_items.blank?
    return button_template_payload if select_items.any? { |item| item['uri'].present? }

    quick_replies_payload
  end

  def select_items
    return [] unless message.content_type == 'input_select'

    message.content_attributes['items'] || []
  end

  # https://developers.facebook.com/documentation/business-messaging/instagram-messaging/features/quick-replies
  def quick_replies_payload
    {
      text: message.outgoing_content,
      quick_replies: select_items.map do |item|
        {
          content_type: 'text',
          payload: item['title'],
          title: item['title']
        }
      end
    }
  end

  # Only web_url buttons are used here: postback taps arrive on the `messaging_postbacks` webhook,
  # which we do not consume, so their replies would be silently dropped.
  # https://developers.facebook.com/docs/instagram-platform/instagram-api-with-instagram-login/messaging-api/button-template/
  def button_template_payload
    {
      attachment: {
        type: 'template',
        payload: {
          template_type: 'button',
          text: message.outgoing_content,
          buttons: select_items.map { |item| { type: 'web_url', title: item['title'], url: item['uri'] } }
        }
      }
    }
  end

  def attachment_message_params(attachment)
    params = {
      recipient: { id: contact.get_source_id(inbox.id) },
      message: {
        attachment: {
          type: attachment_type(attachment),
          payload: {
            url: attachment.download_url
          }
        }
      }
    }

    merge_human_agent_tag(params)
  end

  def process_response(response, message_content)
    parsed_response = response.parsed_response
    if response.success? && parsed_response['error'].blank?
      message.update!(source_id: parsed_response['message_id'])
      parsed_response
    else
      external_error = external_error(parsed_response)
      Rails.logger.error("Instagram response: #{external_error} : #{message_content}")
      Messages::StatusUpdateService.new(message, 'failed', external_error).perform
      nil
    end
  end

  def external_error(response)
    error_message = response.dig('error', 'message')
    error_code = response.dig('error', 'code')

    # https://developers.facebook.com/docs/messenger-platform/error-codes
    # Access token has expired or become invalid. This may be due to a password change,
    # removal of the connected app from Instagram account settings, or other reasons.
    channel.authorization_error! if error_code == 190

    "#{error_code} - #{error_message}"
  end

  def attachment_type(attachment)
    return attachment.file_type if %w[image audio video file].include? attachment.file_type

    'file'
  end

  # Methods to be implemented by child classes
  def send_message(message_content)
    raise NotImplementedError, 'Subclasses must implement send_message'
  end

  def merge_human_agent_tag(params)
    raise NotImplementedError, 'Subclasses must implement merge_human_agent_tag'
  end
end
