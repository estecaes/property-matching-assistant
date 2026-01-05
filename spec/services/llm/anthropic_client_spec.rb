# frozen_string_literal: true

require "rails_helper"

RSpec.describe LLM::AnthropicClient do
  describe "#initialize" do
    context "when ANTHROPIC_API_KEY is set" do
      it "initializes successfully" do
        allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return("test-api-key")

        expect { described_class.new }.not_to raise_error
      end
    end

    context "when ANTHROPIC_API_KEY is not set" do
      it "raises error with clear message" do
        allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return(nil)

        expect { described_class.new }.to raise_error("ANTHROPIC_API_KEY environment variable not set")
      end
    end
  end

  describe "#extract_profile" do
    let(:client) do
      allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return("test-api-key")
      described_class.new
    end

    let(:messages) do
      [
        { role: "user", content: "Busco departamento en CDMX" },
        { role: "assistant", content: "¿Cuál es tu presupuesto?" },
        { role: "user", content: "3 millones" }
      ]
    end

    context "with successful API response" do
      let(:api_response) do
        {
          "content" => [
            {
              "text" => '{"budget": 3000000, "city": "CDMX", "confidence": "high"}'
            }
          ]
        }
      end

      it "parses JSON and returns profile hash" do
        allow(client).to receive(:call_api).and_return(api_response)

        result = client.extract_profile(messages)

        expect(result).to eq({
          budget: 3_000_000,
          city: "CDMX",
          confidence: "high"
        })
      end

      it "converts string values to integers for numeric fields" do
        api_response["content"][0]["text"] = '{"budget": "3000000", "bedrooms": "2"}'
        allow(client).to receive(:call_api).and_return(api_response)

        result = client.extract_profile(messages)

        expect(result[:budget]).to eq(3_000_000)
        expect(result[:bedrooms]).to eq(2)
      end

      it "removes nil values with compact" do
        api_response["content"][0]["text"] = '{"budget": 3000000, "city": null}'
        allow(client).to receive(:call_api).and_return(api_response)

        result = client.extract_profile(messages)

        expect(result).to eq({ budget: 3_000_000, confidence: "medium" })
        expect(result).not_to have_key(:city)
      end

      it "sets default confidence to medium when not provided" do
        api_response["content"][0]["text"] = '{"budget": 3000000}'
        allow(client).to receive(:call_api).and_return(api_response)

        result = client.extract_profile(messages)

        expect(result[:confidence]).to eq("medium")
      end
    end

    context "with JSON wrapped in markdown code blocks" do
      let(:api_response) do
        {
          "content" => [
            {
              "text" => "```json\n{\"budget\": 3000000, \"city\": \"CDMX\"}\n```"
            }
          ]
        }
      end

      it "extracts JSON from markdown" do
        allow(client).to receive(:call_api).and_return(api_response)

        result = client.extract_profile(messages)

        expect(result[:budget]).to eq(3_000_000)
        expect(result[:city]).to eq("CDMX")
      end
    end

    context "when API response is missing content" do
      let(:api_response) { {} }

      it "returns empty hash" do
        allow(client).to receive(:call_api).and_return(api_response)

        result = client.extract_profile(messages)

        expect(result).to eq({})
      end
    end

    context "when response content is empty" do
      let(:api_response) do
        { "content" => [] }
      end

      it "returns empty hash" do
        allow(client).to receive(:call_api).and_return(api_response)

        result = client.extract_profile(messages)

        expect(result).to eq({})
      end
    end

    context "when JSON is malformed" do
      let(:api_response) do
        {
          "content" => [
            { "text" => "This is not JSON at all" }
          ]
        }
      end

      it "returns empty hash" do
        allow(client).to receive(:call_api).and_return(api_response)

        result = client.extract_profile(messages)

        expect(result).to eq({})
      end
    end

    context "when API returns error" do
      it "logs error and raises StandardError" do
        allow(client).to receive(:call_api).and_raise(StandardError.new("API request failed: 500"))
        allow(Rails.logger).to receive(:error)

        expect { client.extract_profile(messages) }.to raise_error(StandardError, /API request failed/)
        expect(Rails.logger).to have_received(:error).with(/Anthropic API error/)
      end
    end

    context "when request times out" do
      it "logs error and raises" do
        allow(client).to receive(:call_api).and_raise(Net::ReadTimeout.new("execution expired"))
        allow(Rails.logger).to receive(:error)

        expect { client.extract_profile(messages) }.to raise_error(Net::ReadTimeout)
        expect(Rails.logger).to have_received(:error).with(/Anthropic API error/)
      end
    end
  end

  describe "#call_api" do
    let(:client) do
      allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return("test-api-key")
      described_class.new
    end

    let(:request_body) do
      {
        model: "claude-3-5-sonnet-20241022",
        max_tokens: 1024,
        messages: []
      }
    end

    context "when API returns success" do
      it "parses and returns JSON response" do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(
            status: 200,
            body: '{"content": [{"text": "response"}]}',
            headers: { "Content-Type" => "application/json" }
          )

        result = client.send(:call_api, request_body)

        expect(result).to eq({ "content" => [ { "text" => "response" } ] })
      end
    end

    context "when API returns 500 error" do
      it "raises error with status code and body" do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(
            status: 500,
            body: '{"error": "Internal server error"}',
            headers: { "Content-Type" => "application/json" }
          )

        expect {
          client.send(:call_api, request_body)
        }.to raise_error(/API request failed: 500/)
      end
    end

    context "when API returns 429 rate limit" do
      it "raises error with rate limit message" do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(
            status: 429,
            body: '{"error": "Rate limit exceeded"}',
            headers: { "Content-Type" => "application/json" }
          )

        expect {
          client.send(:call_api, request_body)
        }.to raise_error(/API request failed: 429/)
      end
    end

    context "when API returns 503 service unavailable" do
      it "raises error with service unavailable message" do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_return(
            status: 503,
            body: '{"error": "Service temporarily unavailable"}',
            headers: { "Content-Type" => "application/json" }
          )

        expect {
          client.send(:call_api, request_body)
        }.to raise_error(/API request failed: 503/)
      end
    end

    context "when request times out" do
      it "raises timeout error" do
        stub_request(:post, "https://api.anthropic.com/v1/messages")
          .to_timeout

        expect {
          client.send(:call_api, request_body)
        }.to raise_error(Net::OpenTimeout)
      end
    end
  end

  describe "#build_request" do
    let(:client) do
      allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return("test-api-key")
      described_class.new
    end

    let(:messages) do
      [
        { role: "user", content: "Hola" },
        { role: "assistant", content: "¿Cómo te ayudo?" }
      ]
    end

    it "builds request with correct model" do
      request = client.send(:build_request, messages)

      expect(request[:model]).to eq("claude-sonnet-4-5")
    end

    it "sets max_tokens to 1024" do
      request = client.send(:build_request, messages)

      expect(request[:max_tokens]).to eq(1024)
    end

    it "includes system prompt" do
      request = client.send(:build_request, messages)

      expect(request[:system]).to include("lead qualification assistant")
      expect(request[:system]).to include("budget")
      expect(request[:system]).to include("phone")
    end

    it "maps messages to API format" do
      request = client.send(:build_request, messages)

      expect(request[:messages]).to eq([
        { role: "user", content: "Hola" },
        { role: "assistant", content: "¿Cómo te ayudo?" }
      ])
    end
  end

  describe "#system_prompt" do
    let(:client) do
      allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return("test-api-key")
      described_class.new
    end

    it "includes all required fields" do
      prompt = client.send(:system_prompt)

      expect(prompt).to include("budget")
      expect(prompt).to include("city")
      expect(prompt).to include("area")
      expect(prompt).to include("bedrooms")
      expect(prompt).to include("bathrooms")
      expect(prompt).to include("property_type")
      expect(prompt).to include("phone")
    end

    it "warns about phone vs budget confusion" do
      prompt = client.send(:system_prompt)

      expect(prompt).to include("do not confuse phone numbers with budgets")
    end

    it "provides example output" do
      prompt = client.send(:system_prompt)

      expect(prompt).to include("Example output")
      expect(prompt).to include('"budget": 3000000')
    end
  end
end
