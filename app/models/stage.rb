# frozen_string_literal: true

# == Schema Information
#
# Table name: stages
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  position        :integer          default(0), not null
#  win_probability :integer          default(0)
#  rotting_days    :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  pipeline_id     :bigint           not null
#
# Indexes
#
#  index_stages_on_pipeline_id               (pipeline_id)
#  index_stages_on_pipeline_id_and_position  (pipeline_id,position) UNIQUE
#

class Stage < ApplicationRecord
  belongs_to :pipeline
  has_many :deals, dependent: :restrict_with_error

  validates :name, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :win_probability, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :rotting_days, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :stage_type, inclusion: { in: %w[not_started active done closed] }

  before_validation :set_default_position, on: :create

  scope :ordered, -> { order(position: :asc) }

  delegate :account, to: :pipeline

  def deals_count
    deals.where(status: 'open').count
  end

  def total_value
    0.0
  end

  private

  def set_default_position
    return if position.present? && position >= 0

    max_position = pipeline&.stages&.maximum(:position) || -1
    self.position = max_position + 1
  end
end
