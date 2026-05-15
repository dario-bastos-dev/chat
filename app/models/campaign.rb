# == Schema Information
#
# Table name: campaigns
#
#  id                                 :bigint           not null, primary key
#  audience                           :jsonb
#  campaign_status                    :integer          default("active"), not null
#  campaign_type                      :integer          default("ongoing"), not null
#  description                        :text
#  enabled                            :boolean          default(TRUE)
#  message                            :text             not null
#  scheduled_at                       :datetime
#  template_params                    :jsonb
#  title                              :string           not null
#  trigger_only_during_business_hours :boolean          default(FALSE)
#  trigger_rules                      :jsonb
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  account_id                         :bigint           not null
#  display_id                         :integer          not null
#  inbox_id                           :bigint           not null
#  sender_id                          :integer
#
# Indexes
#
#  index_campaigns_on_account_id       (account_id)
#  index_campaigns_on_campaign_status  (campaign_status)
#  index_campaigns_on_campaign_type    (campaign_type)
#  index_campaigns_on_inbox_id         (inbox_id)
#  index_campaigns_on_scheduled_at     (scheduled_at)
#
class Campaign < ApplicationRecord
  include UrlHelper
  validates :account_id, presence: true
  validates :inbox_id, presence: true
  validates :title, presence: true
  validate :message_or_attachment_present
  validate :validate_campaign_inbox
  validate :validate_url
  validate :prevent_completed_campaign_from_update, on: :update
  validate :sender_must_belong_to_account
  validate :inbox_must_belong_to_account

  def message_or_attachment_present
    return if message.present? || attachments.attached?

    errors.add(:message, 'must be present if no attachments are provided')
  end

  belongs_to :account
  belongs_to :inbox
  belongs_to :sender, class_name: 'User', optional: true

  enum campaign_type: { ongoing: 0, one_off: 1 }
  # TODO : enabled attribute is unneccessary . lets move that to the campaign status with additional statuses like draft, disabled etc.
  enum campaign_status: { active: 0, completed: 1 }

  has_many :conversations, dependent: :nullify, autosave: true
  has_many_attached :attachments

  before_validation :ensure_message_not_nil
  before_validation :ensure_correct_campaign_attributes
  after_commit :set_display_id, unless: :display_id?
  after_create_commit :dispatch_create_event
  after_update_commit :dispatch_update_event
  after_destroy_commit :dispatch_destroy_event

  def trigger!
    return unless one_off?
    return if completed?

    execute_campaign
  end

  def normalized_audience
    return [] if audience.blank?

    if audience.is_a?(Array)
      audience
    elsif audience.is_a?(Hash) && audience.keys.all? { |k| k.to_s =~ /\A\d+\z/ }
      audience.values
    else
      [audience]
    end
  end

  def total_contacts
    return 0 if audience.blank?

    # Handle cases where audience might be a single Hash or a Rails-indexed Hash
    audience_list = normalized_audience

    target_type = audience_list.find { |a| a.is_a?(Hash) && a['type'] == 'Target' }&.dig('value') || 'contacts'
    audience_label_ids = audience_list.select { |a| a.is_a?(Hash) && a['type'] == 'Label' }.map { |a| a['id'] }
    audience_labels = account.labels.where(id: audience_label_ids).pluck(:title)

    if target_type == 'conversations'
      account.conversations.where(inbox_id: inbox_id, status: :open).tagged_with(audience_labels, any: true).count
    else
      account.contacts.tagged_with(audience_labels, any: true).count
    end
  end

  def push_event_data
    {
      id: id,
      display_id: display_id,
      title: title,
      description: description,
      message: message,
      sender_id: sender_id,
      enabled: enabled,
      campaign_status: campaign_status,
      campaign_type: campaign_type,
      scheduled_at: scheduled_at,
      trigger_only_during_business_hours: trigger_only_during_business_hours,
      trigger_rules: trigger_rules,
      audience: audience,
      account_id: account_id,
      inbox_id: inbox_id
    }
  end

  private

  def ensure_message_not_nil
    self.message ||= ''
  end

  def execute_campaign
    case inbox.inbox_type
    when 'Twilio SMS'
      Twilio::OneoffSmsCampaignService.new(campaign: self).perform
    when 'Sms'
      Sms::OneoffSmsCampaignService.new(campaign: self).perform
    when 'Whatsapp', 'API'
      Whatsapp::OneoffCampaignService.new(campaign: self).perform if account.feature_enabled?(:whatsapp_campaign)
    end
  end

  def set_display_id
    reload
  end

  def dispatch_create_event
    Dispatcher.dispatch(Events::Types::CAMPAIGN_CREATED, Time.zone.now, campaign: self)
  end

  def dispatch_update_event
    Dispatcher.dispatch(Events::Types::CAMPAIGN_UPDATED, Time.zone.now, campaign: self)
  end

  def dispatch_destroy_event
    Dispatcher.dispatch(Events::Types::CAMPAIGN_DELETED, Time.zone.now, campaign_data: push_event_data)
  end

  def validate_campaign_inbox
    return unless inbox

    errors.add :inbox, 'Unsupported Inbox type' unless ['Website', 'Twilio SMS', 'Sms', 'Whatsapp', 'API'].include? inbox.inbox_type
  end

  # TO-DO we clean up with better validations when campaigns evolve into more inboxes
  def ensure_correct_campaign_attributes
    return if inbox.blank?

    if ['Twilio SMS', 'Sms', 'Whatsapp', 'API'].include?(inbox.inbox_type)
      self.campaign_type = 'one_off'
      self.scheduled_at ||= Time.now.utc
    else
      self.campaign_type = 'ongoing'
      self.scheduled_at = nil
    end
  end

  def validate_url
    return unless trigger_rules['url']

    use_http_protocol = trigger_rules['url'].starts_with?('http://') || trigger_rules['url'].starts_with?('https://')
    errors.add(:url, 'invalid') if inbox.inbox_type == 'Website' && !use_http_protocol
  end

  def inbox_must_belong_to_account
    return unless inbox

    return if inbox.account_id == account_id

    errors.add(:inbox_id, 'must belong to the same account as the campaign')
  end

  def sender_must_belong_to_account
    return unless sender

    return if account.users.exists?(id: sender.id)

    errors.add(:sender_id, 'must belong to the same account as the campaign')
  end

  def prevent_completed_campaign_from_update
    errors.add :status, 'The campaign is already completed' if !campaign_status_changed? && completed?
  end

  # creating db triggers
  trigger.before(:insert).for_each(:row) do
    "NEW.display_id := nextval('camp_dpid_seq_' || NEW.account_id);"
  end
end
