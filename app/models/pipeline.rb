# frozen_string_literal: true

# == Schema Information
#
# Table name: pipelines
#
#  id               :bigint           not null, primary key
#  name             :string           not null
#  is_default       :boolean          default(FALSE)
#  lost_reasons     :jsonb            default([])
#  visibility       :string           default("public")
#  allowed_team_ids :jsonb            default([])
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
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

  accepts_nested_attributes_for :stages, allow_destroy: true

  validates :name, presence: true
  validates :account_id, presence: true
  validates :visibility, inclusion: { in: %w[public restricted] }

  before_save :ensure_at_least_one_default
  before_save :ensure_single_default
  before_destroy :migrate_deals, prepend: true

  scope :default_pipeline, -> { where(is_default: true).first }

  private

  def ensure_at_least_one_default
    if !is_default && !account.pipelines.where.not(id: id).exists?(is_default: true)
      self.is_default = true
    end
  end

  def ensure_single_default
    return unless is_default && is_default_changed?

    account.pipelines.where.not(id: id).update_all(is_default: false)
  end

  def migrate_deals
    if deals.exists?
      # Find another pipeline in the same account
      target_pipeline = account.pipelines.where.not(id: id).find_by(is_default: true) ||
                        account.pipelines.where.not(id: id).first

      if target_pipeline
        target_stage = target_pipeline.stages.find_by(stage_type: 'not_started') ||
                       target_pipeline.stages.order(position: :asc).first

        if target_stage
          deals.update_all(pipeline_id: target_pipeline.id, stage_id: target_stage.id)
          
          # Limpa vigorosamente os caches de associação na memória do Rails para garantir que as verificações de dependência do ActiveRecord passem
          deals.reset
          deals.reload if deals.loaded?
          stages.reload
          stages.each do |stage|
            stage.deals.reset
            stage.deals.reload if stage.deals.loaded?
          end
        else
          errors.add(:base, 'O pipeline de destino não possui etapas válidas para migração dos negócios.')
          throw(:abort)
        end
      else
        errors.add(:base, 'Não é possível excluir o único pipeline quando existem negócios associados a ele. Crie outro pipeline primeiro.')
        throw(:abort)
      end
    end
  end
end
