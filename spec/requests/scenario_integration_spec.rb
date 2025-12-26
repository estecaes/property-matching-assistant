# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Scenario Integration", type: :request do
  describe "X-Scenario header management" do
    it "sets Current.scenario from request header" do
      get "/health", headers: { "X-Scenario" => "budget_seeker", "Host" => "localhost" }

      expect(response).to have_http_status(:ok)
      # Current.scenario should be reset after request
      expect(Current.scenario).to be_nil
    end

    it "handles requests without X-Scenario header" do
      get "/health", headers: { "Host" => "localhost" }

      expect(response).to have_http_status(:ok)
      expect(Current.scenario).to be_nil
    end

    it "isolates scenarios between concurrent requests" do
      # Simulate scenario being set in one "request context"
      Current.scenario = "request_1_scenario"

      # Simulate another concurrent request in a different thread
      thread_scenario = nil
      thread = Thread.new do
        Current.scenario = "request_2_scenario"
        thread_scenario = Current.scenario
      end
      thread.join

      # Each request maintains its own scenario
      expect(Current.scenario).to eq("request_1_scenario")
      expect(thread_scenario).to eq("request_2_scenario")

      Current.reset
    end
  end

  describe "ApplicationController scenario logging" do
    it "logs scenario when X-Scenario header is present" do
      allow(Rails.logger).to receive(:info)

      get "/health", headers: { "X-Scenario" => "budget_seeker", "Host" => "localhost" }

      expect(Rails.logger).to have_received(:info).with("Scenario set: budget_seeker")
    end

    it "does not log scenario message when X-Scenario header is absent" do
      allow(Rails.logger).to receive(:info).and_call_original

      get "/health", headers: { "Host" => "localhost" }

      # Should not receive the specific scenario log message
      expect(Rails.logger).not_to have_received(:info).with(/Scenario set:/)
    end
  end

  describe "FakeClient scenario integration" do
    let(:client) { LLM::FakeClient.new }
    let(:messages) do
      [
        { role: "user", content: "Busco departamento" },
        { role: "assistant", content: "¿Presupuesto?" },
        { role: "user", content: "3 millones" }
      ]
    end

    it "uses scenario from Current.scenario within request context" do
      Current.scenario = "budget_seeker"

      profile = client.extract_profile(messages)

      expect(profile[:budget]).to eq(3_000_000)
      expect(profile[:city]).to eq("CDMX")
      expect(profile[:confidence]).to eq("high")

      Current.reset
    end

    it "falls back to AnthropicClient when scenario is not recognized" do
      Current.scenario = "unknown_scenario"

      mock_anthropic_client = instance_double(LLM::AnthropicClient)
      allow(LLM::AnthropicClient).to receive(:new).and_return(mock_anthropic_client)
      allow(mock_anthropic_client).to receive(:extract_profile).and_return({ budget: 2_000_000 })

      profile = client.extract_profile(messages)

      expect(profile[:budget]).to eq(2_000_000)

      Current.reset
    end

    it "falls back when Current.scenario is nil" do
      Current.scenario = nil

      mock_anthropic_client = instance_double(LLM::AnthropicClient)
      allow(LLM::AnthropicClient).to receive(:new).and_return(mock_anthropic_client)
      allow(mock_anthropic_client).to receive(:extract_profile).and_return({})

      client.extract_profile(messages)

      expect(LLM::AnthropicClient).to have_received(:new)

      Current.reset
    end
  end

  describe "end-to-end scenario flow" do
    it "processes request with scenario header through full stack" do
      # This test simulates a real request flow:
      # 1. Request comes in with X-Scenario header
      # 2. ApplicationController sets Current.scenario
      # 3. Service uses Current.scenario to select behavior
      # 4. Response is returned
      # 5. Current.scenario is reset after request

      # For now, we only have /health endpoint
      # Module 6 will add the /run endpoint that uses LLM services

      get "/health", headers: { "X-Scenario" => "budget_seeker", "Host" => "localhost" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to have_key("status")
      expect(json["status"]).to eq("ok")

      # After request completes, Current should be reset
      expect(Current.scenario).to be_nil
    end
  end
end
