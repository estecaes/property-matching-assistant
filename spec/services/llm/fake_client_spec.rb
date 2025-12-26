# frozen_string_literal: true

require "rails_helper"

RSpec.describe LLM::FakeClient do
  subject(:client) { described_class.new }

  # Ensure Current.scenario is reset after each test to prevent state leakage
  after { Current.reset }

  let(:messages) do
    [
      { role: "user", content: "Busco un departamento" },
      { role: "assistant", content: "¿En qué zona?" },
      { role: "user", content: "Roma Norte, 2 recámaras, presupuesto 3 millones" }
    ]
  end

  describe "#extract_profile" do
    context "with budget_seeker scenario" do
      before { Current.scenario = "budget_seeker" }

      it "returns predefined LLM response" do
        profile = client.extract_profile(messages)

        expect(profile).to eq({
          budget: 3_000_000,
          city: "CDMX",
          area: "Roma Norte",
          bedrooms: 2,
          confidence: "high"
        })
      end
    end

    context "with budget_mismatch scenario" do
      before { Current.scenario = "budget_mismatch" }

      it "returns LLM response with first budget mentioned" do
        profile = client.extract_profile(messages)

        expect(profile).to eq({
          budget: 5_000_000,
          city: "Guadalajara",
          property_type: "departamento",
          confidence: "medium"
        })
      end

      it "differs from heuristic response for anti-injection testing" do
        llm_response = client.extract_profile(messages)
        heuristic_response = described_class.heuristic_response("budget_mismatch")

        expect(llm_response[:budget]).to eq(5_000_000)
        expect(heuristic_response[:budget]).to eq(3_000_000)
      end
    end

    context "with phone_vs_budget scenario" do
      before { Current.scenario = "phone_vs_budget" }

      it "correctly distinguishes phone from budget" do
        profile = client.extract_profile(messages)

        expect(profile[:budget]).to eq(3_000_000)
        expect(profile[:phone]).to eq("5512345678")
        expect(profile[:city]).to eq("Monterrey")
        expect(profile[:property_type]).to eq("casa")
      end

      it "heuristic also extracts correct budget (not phone)" do
        heuristic_response = described_class.heuristic_response("phone_vs_budget")

        expect(heuristic_response[:budget]).to eq(3_000_000)
        expect(heuristic_response[:budget]).not_to eq(5512345678)
      end
    end

    context "with unknown scenario" do
      before do
        Current.scenario = "unknown_scenario"
        allow(Rails.logger).to receive(:info)
      end

      it "logs fallback message" do
        # Mock AnthropicClient to avoid real API call
        mock_client = instance_double(LLM::AnthropicClient)
        allow(LLM::AnthropicClient).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:extract_profile).and_return({ budget: 1_000_000 })

        client.extract_profile(messages)

        expect(Rails.logger).to have_received(:info).with("No scenario match, falling back to AnthropicClient")
      end

      it "delegates to AnthropicClient" do
        mock_client = instance_double(LLM::AnthropicClient)
        allow(LLM::AnthropicClient).to receive(:new).and_return(mock_client)
        expect(mock_client).to receive(:extract_profile).with(messages).and_return({ budget: 1_500_000 })

        result = client.extract_profile(messages)

        expect(result).to eq({ budget: 1_500_000 })
      end
    end

    context "with nil scenario" do
      before { Current.scenario = nil }

      it "falls back to AnthropicClient" do
        mock_client = instance_double(LLM::AnthropicClient)
        allow(LLM::AnthropicClient).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:extract_profile).and_return({})

        client.extract_profile(messages)

        expect(LLM::AnthropicClient).to have_received(:new)
      end
    end
  end

  describe ".scenario_messages" do
    it "returns messages for budget_seeker scenario" do
      messages = described_class.scenario_messages("budget_seeker")

      expect(messages).to be_an(Array)
      expect(messages.length).to eq(5)
      expect(messages.first[:role]).to eq("user")
      expect(messages.first[:content]).to eq("Busco un departamento en CDMX")
    end

    it "returns messages for budget_mismatch scenario" do
      messages = described_class.scenario_messages("budget_mismatch")

      expect(messages.length).to eq(3)
      expect(messages.last[:content]).to include("5 millones")
      expect(messages.last[:content]).to include("3")
    end

    it "returns messages for phone_vs_budget scenario" do
      messages = described_class.scenario_messages("phone_vs_budget")

      expect(messages.length).to eq(3)
      expect(messages.last[:content]).to include("3 millones")
      expect(messages.last[:content]).to include("5512345678")
    end

    it "returns empty array for unknown scenario" do
      messages = described_class.scenario_messages("unknown")
      expect(messages).to eq([])
    end
  end

  describe ".heuristic_response" do
    it "returns heuristic data for budget_seeker scenario" do
      response = described_class.heuristic_response("budget_seeker")

      expect(response).to eq({
        budget: 3_000_000,
        city: "CDMX",
        area: "Roma Norte",
        bedrooms: 2,
        property_type: "departamento"
      })
    end

    it "returns heuristic data for budget_mismatch scenario" do
      response = described_class.heuristic_response("budget_mismatch")

      expect(response[:budget]).to eq(3_000_000)
      expect(response[:city]).to eq("Guadalajara")
    end

    it "returns heuristic data for phone_vs_budget scenario" do
      response = described_class.heuristic_response("phone_vs_budget")

      expect(response[:budget]).to eq(3_000_000)
      expect(response[:property_type]).to eq("casa")
    end

    it "returns empty hash for unknown scenario" do
      response = described_class.heuristic_response("unknown")
      expect(response).to eq({})
    end
  end

  describe "SCENARIOS constant" do
    it "is frozen to prevent modification" do
      expect(LLM::FakeClient::SCENARIOS).to be_frozen
    end

    it "contains all expected scenarios" do
      expect(LLM::FakeClient::SCENARIOS.keys).to contain_exactly(
        "budget_seeker",
        "budget_mismatch",
        "phone_vs_budget"
      )
    end

    it "each scenario has required keys" do
      LLM::FakeClient::SCENARIOS.each do |name, data|
        expect(data).to have_key(:messages)
        expect(data).to have_key(:llm_response)
        expect(data).to have_key(:heuristic_response)
      end
    end
  end
end
