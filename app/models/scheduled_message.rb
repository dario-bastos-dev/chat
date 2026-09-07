# == Schema Information
#
# Table name: scheduled_messages
#
#  id              :bigint           not null, primary key
#  account_id      :bigint           not null
#  conversation_id :bigint           not null
#  created_by_id   :bigint           not null
#  title           :string           not null
#  content         :text             not null
#  scheduled_at    :datetime         not null
#  status          :integer          default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_scheduled_messages_on_account_id       (account_id)
#  index_scheduled_messages_on_conversation_id  (conversation_id)
#  idx_sched_msgs_dispatch                      (account_id, status, scheduled_at)
#
class ScheduledMessage < ApplicationRecord
  belongs_to :account
  belongs_to :conversation
  belongs_to :created_by, class_name: 'User'
  # Origem do agendamento quando ele parte do Kanban; a mensagem continua sendo da conversa.
  belongs_to :deal, optional: true

  enum status: { pending: 0, sent: 1, cancelled: 2 }

  validates :title, :content, :scheduled_at, presence: true
  validate :scheduled_at_must_be_in_future, on: :create
  validate :template_required_for_whatsapp_cloud, on: :create

  after_commit :broadcast_status_change

  scope :dispatchable, -> { pending.where(scheduled_at: ..Time.current) }

  private

  def broadcast_status_change
    tokens = (conversation.inbox.members.pluck(:pubsub_token) + account.administrators.pluck(:pubsub_token)).uniq
    payload = as_json.merge(account_id: account_id)
    
    event_name = if previously_new_record?
                   'scheduled_message.created'
                 elsif destroyed?
                   'scheduled_message.deleted'
                 else
                   'scheduled_message.updated'
                 end

    ::ActionCableBroadcastJob.perform_later(tokens, event_name, payload)
  end

  def scheduled_at_must_be_in_future
    return if scheduled_at.blank?

    errors.add(:scheduled_at, 'must be in the future') if scheduled_at < 5.minutes.ago
  end

  def template_required_for_whatsapp_cloud
    return if scheduled_at.blank? || conversation.blank?

    inbox = conversation.inbox
    return unless inbox&.channel_type == 'Channel::Whatsapp'
    return unless inbox.channel&.provider == 'whatsapp_cloud'

    last_incoming = conversation.last_incoming_message
    if last_incoming.present?
      return if scheduled_at <= (last_incoming.created_at + 24.hours)
    end

    errors.add(:template_params, 'is required for WhatsApp Business when scheduling beyond 24 hours') if template_params.blank?
  end
end
