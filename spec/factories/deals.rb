# frozen_string_literal: true

FactoryBot.define do
  factory :deal do
    sequence(:title) { |n| "Deal #{n}" }
    account
    contact { association :contact, account: account }
    pipeline { association :pipeline, account: account }
    stage { association :stage, pipeline: pipeline }
  end
end
