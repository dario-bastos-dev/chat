# frozen_string_literal: true

# == Schema Information
#
# Table name: deal_activities
#
#  id            :bigint           not null, primary key
#  activity_type :string(50)       not null
#  description   :text
#  due_date      :datetime
#  completed_at  :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  deal_id       :bigint           not null
#  account_id    :bigint           not null
#  user_id       :bigint
#
# Indexes
#
#  idx_deal_activities_by_type         (deal_id,activity_type)
#  index_deal_activities_on_account_id (account_id)
#  index_deal_activities_on_deal_id    (deal_id)
#  index_deal_activities_on_due_date   (due_date)
#  index_deal_activities_on_user_id    (user_id)
#

class DealActivity < ApplicationRecord
  ACTIVITY_TYPES = %w[call email meeting task note].freeze

  belongs_to :deal
  belongs_to :account
  belongs_to :user, optional: true

  validates :activity_type, presence: true, inclusion: { in: ACTIVITY_TYPES }
  validates :deal_id, presence: true
  validates :account_id, presence: true

  before_validation :set_account_from_deal, on: :create

  after_create_commit :update_deal_last_activity
  after_update_commit :update_deal_last_activity, if: :saved_change_to_completed_at?

  scope :pending, -> { where(completed_at: nil) }
  scope :completed, -> { where.not(completed_at: nil) }
  scope :overdue, -> { pending.where('due_date < ?', Time.current) }
  scope :by_type, ->(type) { where(activity_type: type) }
  scope :ordered_by_due_date, -> { order(due_date: :asc) }

  def completed?
    completed_at.present?
  end

  def overdue?
    !completed? && due_date.present? && due_date < Time.current
  end

  def mark_as_completed!
    update!(completed_at: Time.current)
  end

  private

  def set_account_from_deal
    return if account_id.present?
    return unless deal.present?

    self.account_id = deal.account_id
  end

  def update_deal_last_activity
    deal.update(last_activity_at: Time.current)
  end
end
