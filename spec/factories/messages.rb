FactoryBot.define do
  factory :message do
    association :conversation_session
    role { "user" }
    content { "Busco un departamento en CDMX" }
    sequence(:sequence_number) { |n| n }

    trait :user do
      role { "user" }
    end

    trait :assistant do
      role { "assistant" }
      content { "¿En qué zona te gustaría?" }
    end
  end
end
