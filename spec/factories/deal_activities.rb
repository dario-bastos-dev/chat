# frozen_string_literal: true

FactoryBot.define do
  factory :deal_activity do
    deal
    account { deal.account }
    user
    activity_type { 'note' }
    description { Faker::Lorem.sentence }
  end
end
