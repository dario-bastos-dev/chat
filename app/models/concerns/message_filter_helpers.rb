module MessageFilterHelpers
  extend ActiveSupport::Concern

  def reportable?
    incoming? || outgoing?
  end

  def webhook_sendable?
    incoming? || outgoing? || template?
  end

  def slack_hook_sendable?
    incoming? || outgoing? || template?
  end

  def notifiable?
    (incoming? || outgoing?) && !private? && !csat_flow_reply?
  end

  # A tapped CSAT flow button answers the survey, it is not the contact coming back for help: it
  # neither reopens the conversation nor notifies the agent. Flagged on create, see Message.
  def csat_flow_reply?
    content_attributes['csat_flow_reply'].present?
  end

  def conversation_transcriptable?
    incoming? || outgoing?
  end

  def email_reply_summarizable?
    incoming? || outgoing? || input_csat?
  end

  def instagram_story_mention?
    inbox.instagram? && try(:content_attributes)[:image_type] == 'story_mention'
  end
end
