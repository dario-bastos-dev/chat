FactoryBot.define do
  factory :message_sequence do
    association :account
    name { "Sequência de Teste" }
    activation_type { :tag }
    activation_tag { "teste-funil" }
    inbox_scope { :all_inboxes }
    active { true }
  end
end
