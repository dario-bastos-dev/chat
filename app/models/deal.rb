# frozen_string_literal: true

# == Schema Information
#
# Table name: deals
#
#  id                :bigint           not null, primary key
#  title             :string(500)      not null
#  status            :string(50)       default("open")
#  lost_reason       :string(255)
#  custom_attributes :jsonb            default({})
#  last_activity_at  :datetime
#  won_at            :datetime
#  lost_at           :datetime
#  position          :integer          default(0)
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  pipeline_id       :bigint           not null
#  stage_id          :bigint           not null
#  contact_id        :bigint           not null
#  inbox_id          :bigint
#  assignee_id       :bigint
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
  include Labelable

  STATUSES = %w[open won lost].freeze

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
  validates :lost_reason, presence: true, if: -> { status == 'lost' }

  validate :stage_belongs_to_pipeline

  before_validation :set_pipeline_from_stage
  before_validation :sync_status_with_stage_type
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

  # Le a coluna de cache direto, como Conversation#cached_label_list_array.
  # `label_list` do acts_as_taggable_on consulta `taggings` a cada chamada, via
  # add_custom_context, mesmo com o cache preenchido — o que dava uma query por
  # negocio na listagem do Kanban.
  def cached_label_list_array
    (cached_label_list || '').split(',').map(&:strip).reject(&:blank?)
  end

  # Check if deal is rotting (no activity for X days)
  def rotting?
    return false unless stage.rotting_days.present?
    return false if last_activity_at.nil?

    last_activity_at < stage.rotting_days.days.ago
  end

  def mark_as_won!
    target_stage = pipeline.stages.find_by(stage_type: 'done')
    if target_stage.present?
      self.stage = target_stage
    end
    self.status = 'won'
    self.won_at = Time.current
    self.lost_at = nil
    self.lost_reason = nil
    save!
  end

  def mark_as_lost!(reason)
    target_stage = pipeline.stages.find_by(stage_type: 'closed')
    if target_stage.present?
      self.stage = target_stage
    end
    self.status = 'lost'
    self.lost_at = Time.current
    self.lost_reason = reason
    self.won_at = nil
    save!
  end

  def mark_as_rotting!
    return if custom_attributes['is_rotting']

    self.custom_attributes['is_rotting'] = true
    save!
    dispatch_rotting_event
  end

  # O evento `deal.stage_changed` sai do after_update_commit, que ja observa a
  # mudanca de stage_id. Despachar aqui tambem duplicava o evento e gerava duas
  # notas de atividade a cada arrasto no Kanban.
  def move_to_stage!(new_stage, new_position = nil)
    self.stage = new_stage
    self.position = new_position if new_position.present?
    self.last_activity_at = Time.current
    save!
  end



  def webhook_data
    {
      id: id,
      title: title,
      status: status,
      stage_id: stage_id,
      pipeline_id: pipeline_id,
      contact_id: contact_id,
      assignee_id: assignee_id,
      account_id: account_id,
      last_activity_at: last_activity_at&.to_i,
      created_at: created_at.to_i,
      updated_at: updated_at.to_i
    }
  end

  def push_event_data
    {
      id: id,
      title: title,
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
    return unless stage.present?

    self.pipeline_id = stage.pipeline_id
  end

  def sync_status_with_stage_type
    return unless stage.present?

    case stage.stage_type
    when 'done'
      self.status = 'won'
      self.won_at ||= Time.current
      self.lost_at = nil
      self.lost_reason = nil
    when 'closed'
      self.status = 'lost'
      self.lost_at ||= Time.current
      self.won_at = nil
      self.lost_reason = 'Movido para a etapa Perdido' if lost_reason.blank?
    when 'not_started', 'active'
      self.status = 'open'
      self.won_at = nil
      self.lost_at = nil
      self.lost_reason = nil
    end
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

    # Dispatch specific events based on what changed
    dispatch_won_event if previous_changes.key?('status') && status == 'won'
    dispatch_lost_event if previous_changes.key?('status') && status == 'lost'
    dispatch_stage_changed_event(previous_changes['stage_id']&.first, stage_id) if previous_changes.key?('stage_id')
  end

  def dispatch_destroy_event
    Rails.configuration.dispatcher.dispatch(DEAL_DELETED, Time.zone.now, deal: self)
  end

  def dispatch_stage_changed_event(from_stage_id, to_stage_id)
    Rails.configuration.dispatcher.dispatch(
      DEAL_STAGE_CHANGED, Time.zone.now,
      deal: self, from_stage_id: from_stage_id, to_stage_id: to_stage_id
    )
  end

  def dispatch_won_event
    Rails.configuration.dispatcher.dispatch(
      DEAL_WON, Time.zone.now,
      deal: self, won_at: won_at
    )
  end

  def dispatch_lost_event
    Rails.configuration.dispatcher.dispatch(
      DEAL_LOST, Time.zone.now,
      deal: self, lost_reason: lost_reason
    )
  end

  def dispatch_rotting_event
    Rails.configuration.dispatcher.dispatch(
      DEAL_ROTTING, Time.zone.now,
      deal: self, days_inactive: last_activity_at.present? ? (Time.current - last_activity_at).to_i / 1.day : 0
    )
  end
end
