FactoryBot.define do
  factory :message_sequence_step do
    association :message_sequence
    sequence(:position) { |n| n }
    step_type { :send_message }
    content { "Olá, esta é uma mensagem de teste." }
    wait_time { "0:00:01:00" } # 1 minuto
  end
end
