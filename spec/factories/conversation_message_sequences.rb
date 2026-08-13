FactoryBot.define do
  factory :conversation_message_sequence do
    association :conversation
    association :message_sequence
    active { true }
    waiting_interaction { false }
  end
end
