FactoryBot.define do
  factory :conversation_message_sequence do
    association :conversation
    association :message_sequence
    active { true }
    current_step { 0 }
    waiting_interaction { false }
  end
end
