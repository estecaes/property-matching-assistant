FactoryBot.define do
  factory :conversation_session do
    lead_profile { {} }
    discrepancies { [] }
    needs_human_review { false }
    turns_count { 0 }
    status { "active" }
    qualification_duration_ms { nil }

    trait :qualified do
      status { "qualified" }
      lead_profile do
        {
          "city" => "CDMX",
          "budget" => 3_000_000,
          "bedrooms" => 2
        }
      end
      turns_count { 5 }
      qualification_duration_ms { 1500 }
    end

    trait :needs_review do
      needs_human_review { true }
      discrepancies do
        [
          { "field" => "budget", "llm" => 5_000_000, "heuristic" => 3_000_000, "diff_pct" => 66.7 }
        ]
      end
    end

    trait :with_city do
      lead_profile { { "city" => "CDMX" } }
    end
  end
end
