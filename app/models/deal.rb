# frozen_string_literal: true

# == Schema Information
#
# Table name: deals
#
#  id                  :bigint           not null, primary key
#  title               :string(500)      not null
#  value               :decimal(15, 2)   default(0.0)
#  currency            :string(3)        default("BRL")
#  status              :string(50)       default("open")
#  lost_reason         :string(255)
#  custom_attributes   :jsonb            default({})
#  last_activity_at    :datetime
#  won_at              :datetime
#  lost_at             :datetime
#  expected_close_date :date
#  position            :integer          default(0)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  pipeline_id         :bigint           not null
#  stage_id            :bigint           not null
#  contact_id          :bigint           not null
#  inbox_id            :bigint
#  assignee_id         :bigint
#
# Indexes
#
#  idx_deals_by_assignee       (account_id,assignee_id,status)
#  idx_deals_by_contact        (contact_id,status)
#  idx_deals_custom_attrs_gin  (custom_attributes) USING gin
#  idx_deals_kanban_listing    (account_id,pipeline_id,stage_id,status)
#  idx_deals_open_only         (account_id,pipeline_id,stage_id) WHERE status = 'open'
#  index_deals_on_last_activity_at  (last_activity_at)
#  index_deals_on_status       (status)
#

class Deal < ApplicationRecord
  include Events::Types

  STATUSES = %w[open won lost].freeze
  CURRENCIES = %w[BRL USD EUR GBP].freeze

  belongs_to :account
  belongs_to :pipeline
  belongs_to :stage
  belongs_to :contact
  belongs_to :inbox, optional: true
  belongs_to :assignee, class_name: 'User', optional: true

  has_many :deal_activities, dependent: :destroy
  has_many :conversation_deals, dependent: :destroy
  has_many :conversations, through: :conversation_deals

  validates :title, presence: true, length: { maximum: 500 }
  validates :account_id, presence: true
  validates :pipeline_id, presence: true
  validates :stage_id, presence: true
  validates :contact_id, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :currency, inclusion: { in: CURRENCIES }
  validates :value, numericality: { greater_than_or_equal_to: 0 }
  validates :lost_reason, presence: true, if: -> { status == 'lost' }

  validate :stage_belongs_to_pipeline

  before_validation :set_pipeline_from_stage, on: :create
  before_save :set_won_or_lost_timestamp
  before_save :update_last_activity_at, if: :will_save_change_to_stage_id?

  after_create_commit :dispatch_create_event
  after_update_commit :dispatch_update_event
  after_destroy_commit :dispatch_destroy_event

  scope :open_deals, -> { where(status: 'open') }
  scope :won_deals, -> { where(status: 'won') }
  scope :lost_deals, -> { where(status: 'lost') }
  scope :by_pipeline, ->(pipeline_id) { where(pipeline_id: pipeline_id) }
  scope :by_stage, ->(stage_id) { where(stage_id: stage_id) }
  scope :by_assignee, ->(assignee_id) { where(assignee_id: assignee_id) }
  scope :ordered_by_position, -> { order(position: :asc) }

  # Check if deal is rotting (no activity for X days)
  def rotting?
    return false unless stage.rotting_days.present?
    return false if last_activity_at.nil?

    last_activity_at < stage.rotting_days.days.ago
  end

  def mark_as_won!
    update!(status: 'won', won_at: Time.current)
  end

  def mark_as_lost!(reason)
    update!(status: 'lost', lost_at: Time.current, lost_reason: reason)
  end

  def move_to_stage!(new_stage, new_position = nil)
    self.stage = new_stage
    self.position = new_position if new_position.present?
    self.last_activity_at = Time.current
    save!
  end

  def weighted_value
    return 0 if value.nil? || stage.win_probability.nil?

    value * (stage.win_probability / 100.0)
  end

  def push_event_data
    {
      id: id,
      title: title,
      value: value,
      status: status,
      stage_id: stage_id,
      contact_id: contact_id,
      assignee_id: assignee_id
    }
  end

  private

  def stage_belongs_to_pipeline
    return unless stage.present? && pipeline.present?
    return if stage.pipeline_id == pipeline_id

    errors.add(:stage, 'must belong to the selected pipeline')
  end

  def set_pipeline_from_stage
    return if pipeline_id.present?
    return unless stage.present?

    self.pipeline_id = stage.pipeline_id
  end

  def set_won_or_lost_timestamp
    if status_changed?
      case status
      when 'won'
        self.won_at ||= Time.current
      when 'lost'
        self.lost_at ||= Time.current
      end
    end
  end

  def update_last_activity_at
    self.last_activity_at = Time.current
  end

  def dispatch_create_event
    Rails.configuration.dispatcher.dispatch(DEAL_CREATED, Time.zone.now, deal: self)
  end

  def dispatch_update_event
    Rails.configuration.dispatcher.dispatch(DEAL_UPDATED, Time.zone.now, deal: self, changed_attributes: previous_changes)
  end

  def dispatch_destroy_event
    Rails.configuration.dispatcher.dispatch(DEAL_DELETED, Time.zone.now, deal: self)
  end
end
