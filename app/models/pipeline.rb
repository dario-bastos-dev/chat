# frozen_string_literal: true

# == Schema Information
#
# Table name: pipelines
#
#  id          :bigint           not null, primary key
#  name        :string           not null
#  is_default  :boolean          default(FALSE)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_pipelines_on_account_id                 (account_id)
#  index_pipelines_on_account_id_and_is_default  (account_id,is_default)
#

class Pipeline < ApplicationRecord
  belongs_to :account
  has_many :stages, -> { order(position: :asc) }, dependent: :destroy, inverse_of: :pipeline
  has_many :deals, dependent: :restrict_with_error

  validates :name, presence: true
  validates :account_id, presence: true
  validates :visibility, inclusion: { in: %w[public restricted] }

  before_save :ensure_single_default

  scope :default_pipeline, -> { where(is_default: true).first }

  def total_value
    deals.where(status: 'open').sum(:value)
  end

  def total_deals_count
    deals.where(status: 'open').count
  end

  private

  def ensure_single_default
    return unless is_default && is_default_changed?

    account.pipelines.where.not(id: id).update_all(is_default: false)
  end
end
