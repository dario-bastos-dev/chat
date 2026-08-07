# frozen_string_literal: true

module Pipelines
  class CreateDefaultService
    # Mirrors the four stages the dashboard proposes when creating a pipeline by
    # hand, so a brand new account starts with a usable funnel.
    DEFAULT_STAGES = [
      { key: 'pending', position: 1, stage_type: 'not_started', color: '#3b82f6', win_probability: 10 },
      { key: 'open', position: 2, stage_type: 'active', color: '#eab308', win_probability: 50 },
      { key: 'won', position: 3, stage_type: 'done', color: '#22c55e', win_probability: 100 },
      { key: 'lost', position: 4, stage_type: 'closed', color: '#ef4444', win_probability: 0 }
    ].freeze

    def initialize(account)
      @account = account
    end

    def perform
      return if @account.pipelines.exists?

      ActiveRecord::Base.transaction do
        pipeline = @account.pipelines.create!(name: I18n.t('default_pipeline.name'), is_default: true)

        DEFAULT_STAGES.each do |attrs|
          pipeline.stages.create!(attrs.except(:key).merge(name: I18n.t("default_pipeline.stages.#{attrs[:key]}")))
        end

        pipeline
      end
    rescue StandardError => e
      Rails.logger.error("[CRM] Failed to create default pipeline for account #{@account.id}: #{e.message}")
      nil
    end
  end
end
