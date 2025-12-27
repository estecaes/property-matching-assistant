# frozen_string_literal: true

require "rails_helper"

RSpec.describe LeadQualifier do
  # Ensure Current.scenario is reset after each test
  after { Current.reset }

  let(:session) { create(:conversation_session, status: "active") }

  describe ".call" do
    context "with budget_seeker scenario (happy path)" do
      before do
        Current.scenario = "budget_seeker"
        create_messages(session, LLM::FakeClient.scenario_messages("budget_seeker"))
      end

      it "qualifies lead without discrepancies" do
        result = described_class.call(session)
        session_result = result[:session]

        expect(session_result.lead_profile["budget"]).to eq(3_000_000)
        expect(session_result.lead_profile["city"]).to eq("CDMX")
        expect(session_result.lead_profile["area"]).to eq("Roma Norte")
        expect(session_result.lead_profile["bedrooms"]).to eq(2)
        expect(session_result.lead_profile["property_type"]).to eq("departamento")
        expect(session_result.discrepancies).to be_empty
        expect(session_result.needs_human_review).to be false
        expect(session_result.status).to eq("qualified")
        expect(session_result.qualification_duration_ms).to be > 0
        expect(result[:extraction_process]).to be_present
      end

      it "logs qualification result" do
        allow(Rails.logger).to receive(:info)

        described_class.call(session)

        expect(Rails.logger).to have_received(:info).with(/LLM extraction/)
        expect(Rails.logger).to have_received(:info).with(/Heuristic extraction/)
        expect(Rails.logger).to have_received(:info).with(/lead_qualified/)
      end
    end

    context "with budget_mismatch scenario (anti-injection)" do
      before do
        Current.scenario = "budget_mismatch"
        create_messages(session, LLM::FakeClient.scenario_messages("budget_mismatch"))
      end

      it "detects budget discrepancy between LLM and heuristic" do
        result = described_class.call(session)
        session_result = result[:session]

        expect(session_result.discrepancies).not_to be_empty

        budget_disc = session_result.discrepancies.find { |d| d["field"] == "budget" }
        expect(budget_disc).to be_present
        expect(budget_disc["llm_value"]).to eq(5_000_000)
        expect(budget_disc["heuristic_value"]).to eq(3_000_000)
        expect(budget_disc["diff_pct"]).to be > 20
        expect(budget_disc["severity"]).to eq("high")
      end

      it "marks session as needing human review" do
        result = described_class.call(session)
        session_result = result[:session]

        expect(session_result.needs_human_review).to be true
      end

      it "prefers heuristic value in final profile (defensive)" do
        result = described_class.call(session)
        session_result = result[:session]

        # Final profile should use heuristic's 3M, not LLM's 5M
        expect(session_result.lead_profile["budget"]).to eq(3_000_000)
      end
    end

    context "with phone_vs_budget scenario (edge case)" do
      before do
        Current.scenario = "phone_vs_budget"
        create_messages(session, LLM::FakeClient.scenario_messages("phone_vs_budget"))
      end

      it "extracts budget correctly, not phone number" do
        result = described_class.call(session)
        session_result = result[:session]

        # Budget should be 3M, NOT the 10-digit phone number
        expect(session_result.lead_profile["budget"]).to eq(3_000_000)
        expect(session_result.lead_profile["budget"]).not_to eq(5_512_345_678)
      end

      it "heuristic correctly ignores phone number" do
        result = described_class.call(session)
        session_result = result[:session]

        # No discrepancy on budget (both extracted 3M)
        budget_disc = session_result.discrepancies.find { |d| d["field"] == "budget" }
        expect(budget_disc).to be_nil
      end

      it "LLM extracts phone but heuristic does not" do
        result = described_class.call(session)
        session_result = result[:session]

        # Phone should be in final profile (from LLM, no conflict)
        expect(session_result.lead_profile["phone"]).to eq("5512345678")
      end
    end

    context "when LLM extraction fails" do
      before do
        Current.scenario = "budget_seeker"
        create_messages(session, LLM::FakeClient.scenario_messages("budget_seeker"))
        
        allow_any_instance_of(LLM::FakeClient).to receive(:extract_profile).and_raise(StandardError.new("API timeout"))
      end

      it "falls back to heuristic-only mode gracefully" do
        result = described_class.call(session)
        session_result = result[:session]

        # Should still qualify using heuristic extraction
        expect(session_result.lead_profile["budget"]).to eq(3_000_000)
        expect(session_result.lead_profile["city"]).to eq("CDMX")
        expect(session_result.status).to eq("qualified")
      end

      it "logs the error" do
        allow(Rails.logger).to receive(:error)
        allow(Rails.logger).to receive(:info)

        described_class.call(session)

        expect(Rails.logger).to have_received(:error).with(/LLM extraction failed/)
      end
    end
  end

  # VCR Integration Tests - Validate real API integration
  context "with real Anthropic API responses (VCR integration)", :vcr do
    before do
      Current.scenario = nil  # Force fallback to AnthropicClient
    end

    it "qualifies lead using phone_vs_budget cassette" do
      # Messages must match cassette request exactly
      session.messages.create!(role: "user", content: "Busco depa en CDMX", sequence_number: 0)
      session.messages.create!(role: "assistant", content: "¿Presupuesto y teléfono?", sequence_number: 1)
      session.messages.create!(role: "user", content: "Presupuesto 2 millones, mi cel es 5512345678", sequence_number: 2)

      VCR.use_cassette("anthropic/phone_vs_budget") do
        result = described_class.call(session)
        session_result = result[:session]

        # Verify with REAL API response
        expect(session_result.lead_profile["budget"]).to eq(2_000_000)
        expect(session_result.lead_profile["phone"]).to eq("5512345678")
        expect(session_result.lead_profile["city"]).to eq("CDMX")
        expect(session_result.lead_profile["property_type"]).to eq("departamento")
        expect(session_result.status).to eq("qualified")
      end
    end

    it "qualifies lead using extract_simple_profile cassette (happy path)" do
      session.messages.create!(role: "user", content: "Busco un departamento en CDMX", sequence_number: 0)
      session.messages.create!(role: "assistant", content: "¿Cuál es tu presupuesto?", sequence_number: 1)
      session.messages.create!(role: "user", content: "Tengo hasta 3 millones de pesos", sequence_number: 2)

      VCR.use_cassette("anthropic/extract_simple_profile") do
        result = described_class.call(session)
        session_result = result[:session]

        expect(session_result.lead_profile["budget"]).to eq(3_000_000)
        expect(session_result.lead_profile["city"]).to eq("CDMX")
        expect(session_result.lead_profile["property_type"]).to eq("departamento")
        expect(session_result.discrepancies).to be_empty
      end
    end

    it "handles markdown-wrapped JSON from API" do
      # Uses cassette with JSON wrapped in ```json...```
      session.messages.create!(role: "user", content: "Busco depa", sequence_number: 0)

      VCR.use_cassette("anthropic/markdown_wrapped_json") do
        result = described_class.call(session)
        session_result = result[:session]

        # Should parse successfully despite markdown wrapper
        expect(session_result.lead_profile).not_to be_empty
        expect(session_result.status).to eq("qualified")
      end
    end
  end

  # Helper method to create messages from scenario
  def create_messages(session, messages)
    messages.each_with_index do |msg, index|
      session.messages.create!(
        role: msg[:role],
        content: msg[:content],
        sequence_number: index
      )
    end
  end
end
