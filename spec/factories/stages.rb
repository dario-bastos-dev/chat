# frozen_string_literal: true

FactoryBot.define do
  factory :stage do
    sequence(:name) { |n| "Stage #{n}" }
    pipeline
    stage_type { 'active' }
    win_probability { 50 }
    color { '#1f93ff' }
  end
end
