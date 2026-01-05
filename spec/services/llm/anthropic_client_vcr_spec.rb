# frozen_string_literal: true

require "rails_helper"

RSpec.describe LLM::AnthropicClient, :vcr do
  # This spec uses VCR to record real API interactions
  # First run: Makes actual API call to Anthropic (costs $)
  # Subsequent runs: Replays from cassette (free, fast, deterministic)

  describe "#extract_profile with real API" do
    let(:client) { described_class.new }

    context "with simple budget question" do
      let(:messages) do
        [
          { role: "user", content: "Busco un departamento en CDMX" },
          { role: "assistant", content: "¿Cuál es tu presupuesto?" },
          { role: "user", content: "Tengo hasta 3 millones de pesos" }
        ]
      end

      it "extracts budget and city from conversation", :vcr do
        VCR.use_cassette("anthropic/extract_simple_profile") do
          profile = client.extract_profile(messages)

          # Verify Claude extracted the information correctly
          expect(profile).to be_a(Hash)
          expect(profile[:budget]).to be_a(Integer)
          expect(profile[:budget]).to be_between(2_900_000, 3_100_000) # Allow some variation
          expect(profile[:city]).to eq("CDMX")
          expect(profile[:confidence]).to be_in([ "high", "medium", "low" ])
        end
      end
    end

    context "with complex multi-field request" do
      let(:messages) do
        [
          { role: "user", content: "Hola, busco casa" },
          { role: "assistant", content: "¿En qué ciudad?" },
          { role: "user", content: "En Monterrey, zona San Pedro" },
          { role: "assistant", content: "¿Cuántas recámaras necesitas?" },
          { role: "user", content: "3 recámaras, 2 baños, presupuesto de 5 millones" }
        ]
      end

      it "extracts all profile fields from conversation", :vcr do
        VCR.use_cassette("anthropic/extract_complex_profile") do
          profile = client.extract_profile(messages)

          expect(profile).to include(
            city: "Monterrey",
            property_type: "casa",
            bedrooms: 3,
            bathrooms: 2
          )
          expect(profile[:budget]).to be_between(4_900_000, 5_100_000)
          expect(profile[:area]).to include("San Pedro") if profile[:area]
        end
      end
    end

    context "with phone number in conversation" do
      let(:messages) do
        [
          { role: "user", content: "Busco depa en CDMX" },
          { role: "assistant", content: "¿Presupuesto y teléfono?" },
          { role: "user", content: "Presupuesto 2 millones, mi cel es 5512345678" }
        ]
      end

      it "distinguishes phone from budget", :vcr do
        VCR.use_cassette("anthropic/phone_vs_budget") do
          profile = client.extract_profile(messages)

          # Critical: Budget should be 2 million, NOT the phone number
          expect(profile[:budget]).to be_between(1_900_000, 2_100_000)
          expect(profile[:budget]).not_to eq(5512345678)

          # Phone should be captured separately if mentioned
          expect(profile[:phone]).to eq("5512345678") if profile[:phone]
        end
      end
    end
  end

  describe "API response format validation" do
    let(:client) { described_class.new }
    let(:simple_messages) do
      [
        { role: "user", content: "Busco depa, presupuesto 1 millón" }
      ]
    end

    it "handles Claude wrapping JSON in markdown", :vcr do
      VCR.use_cassette("anthropic/markdown_wrapped_json") do
        profile = client.extract_profile(simple_messages)

        # Should successfully parse even if Claude wraps response in ```json
        expect(profile).to be_a(Hash)
        expect(profile).not_to be_empty
      end
    end
  end
end
