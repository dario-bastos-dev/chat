# frozen_string_literal: true

FactoryBot.define do
  factory :conversation_deal do
    conversation
    deal
    is_primary { false }
  end
end
