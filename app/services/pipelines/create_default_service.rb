module Pipelines
  class CreateDefaultService
    def initialize(account)
      @account = account
    end

    def perform
      return if @account.pipelines.exists?

      ActiveRecord::Base.transaction do
        pipeline = @account.pipelines.create!(name: 'Funil de Vendas', is_default: true)
        
        ['Abertos', 'Pendentes', 'Fechados'].each_with_index do |stage_name, index|
          pipeline.stages.create!(name: stage_name, position: index + 1)
        end
        
        pipeline
      end
    end
  end
end
