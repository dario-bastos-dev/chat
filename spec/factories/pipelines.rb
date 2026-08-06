# frozen_string_literal: true

FactoryBot.define do
  factory :pipeline do
    sequence(:name) { |n| "Pipeline #{n}" }
    account
    is_default { false }
    visibility { 'public' }
    lost_reasons { [] }
    allowed_team_ids { [] }

    trait :restricted do
      visibility { 'restricted' }
    end

    trait :with_stages do
      after(:create) do |pipeline|
        create(:stage, pipeline: pipeline, name: 'Pendente', stage_type: 'not_started', position: 1, win_probability: 10)
        create(:stage, pipeline: pipeline, name: 'Aberto', stage_type: 'active', position: 2, win_probability: 50)
        create(:stage, pipeline: pipeline, name: 'Ganho', stage_type: 'done', position: 3, win_probability: 100)
        create(:stage, pipeline: pipeline, name: 'Perdido', stage_type: 'closed', position: 4, win_probability: 0)
      end
    end
  end
end
