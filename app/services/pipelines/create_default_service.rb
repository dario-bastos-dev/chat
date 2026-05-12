# frozen_string_literal: true

module Pipelines
  class CreateDefaultService
    DEFAULT_STAGES = [
      { name: 'Qualificação', position: 0, win_probability: 10 },
      { name: 'Contato Feito', position: 1, win_probability: 25 },
      { name: 'Proposta Enviada', position: 2, win_probability: 50 },
      { name: 'Negociação', position: 3, win_probability: 75 },
      { name: 'Fechamento', position: 4, win_probability: 100 }
    ].freeze

    def initialize(account)
      @account = account
    end

    def perform
      return if @account.pipelines.exists?

      ActiveRecord::Base.transaction do
        pipeline = @account.pipelines.create!(name: 'Funil de Vendas', is_default: true)

        DEFAULT_STAGES.each do |stage_attrs|
          pipeline.stages.create!(stage_attrs)
        end

        pipeline
      end
    rescue StandardError => e
      Rails.logger.error("[CRM] Failed to create default pipeline for account #{@account.id}: #{e.message}")
      nil
    end
  end
end
