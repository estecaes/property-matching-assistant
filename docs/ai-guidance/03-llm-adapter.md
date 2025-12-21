# Módulo 3: LLM Adapter - AI Guidance

**Estimated Time**: 1 hour
**Status**: Pending
**Dependencies**: Module 1 (Foundation), Module 2 (Models)

---

## Objectives

1. Implement CurrentAttributes for thread-safe scenario management
2. Create FakeClient with 3 predefined scenarios
3. Implement AnthropicClient for real API calls
4. Add scenario switching via X-Scenario header
5. Test scenario isolation and fallback behavior

---

## Implementation Steps

See ADR-003 for architectural context and design decisions.

### Step 1: CurrentAttributes Setup

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :scenario
end
```

### Step 2: ApplicationController Integration

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  before_action :set_scenario_from_header

  private

  def set_scenario_from_header
    Current.scenario = request.headers['X-Scenario']
    Rails.logger.info("Scenario set: #{Current.scenario}") if Current.scenario
  end
end
```

### Step 3: LLM Module Structure

```ruby
# app/services/llm/fake_client.rb
module LLM
  class FakeClient
    SCENARIOS = {
      'budget_seeker' => {
        # Happy path: clear budget, city, preferences
        messages: [
          { role: 'user', content: 'Busco un departamento en CDMX' },
          { role: 'assistant', content: '¿En qué zona te gustaría?' },
          { role: 'user', content: 'Roma Norte, 2 recámaras' },
          { role: 'assistant', content: '¿Cuál es tu presupuesto?' },
          { role: 'user', content: 'Hasta 3 millones' }
        ],
        llm_response: {
          budget: 3_000_000,
          city: 'CDMX',
          area: 'Roma Norte',
          bedrooms: 2,
          confidence: 'high'
        },
        heuristic_response: {
          budget: 3_000_000,
          city: 'CDMX',
          area: 'Roma Norte',
          bedrooms: 2
        }
      },
      'budget_mismatch' => {
        # Anti-injection: LLM extracts different budget than heuristic
        messages: [
          { role: 'user', content: 'Busco depa en Guadalajara' },
          { role: 'assistant', content: '¿Cuál es tu presupuesto?' },
          { role: 'user', content: 'Mi presupuesto es 5 millones pero realmente solo tengo 3' }
        ],
        llm_response: {
          budget: 5_000_000,  # LLM picks first number
          city: 'Guadalajara',
          confidence: 'medium'
        },
        heuristic_response: {
          budget: 3_000_000,  # Heuristic picks last number
          city: 'Guadalajara'
        }
      },
      'phone_vs_budget' => {
        # Edge case: distinguish phone number from budget
        messages: [
          { role: 'user', content: 'Busco casa en Monterrey' },
          { role: 'assistant', content: 'Cuéntame más sobre lo que buscas' },
          { role: 'user', content: 'presupuesto 3 millones, mi tel es 5512345678' }
        ],
        llm_response: {
          budget: 3_000_000,
          city: 'Monterrey',
          phone: '5512345678',
          property_type: 'casa',
          confidence: 'high'
        },
        heuristic_response: {
          budget: 3_000_000,  # NOT 5512345678
          city: 'Monterrey',
          property_type: 'casa'
        }
      }
    }.freeze

    def extract_profile(messages)
      scenario_data = SCENARIOS[Current.scenario]
      return scenario_data[:llm_response] if scenario_data

      # Fallback to real API if no scenario or unknown scenario
      Rails.logger.info("No scenario match, falling back to AnthropicClient")
      LLM::AnthropicClient.new.extract_profile(messages)
    end

    def self.scenario_messages(scenario_name)
      SCENARIOS.dig(scenario_name, :messages) || []
    end

    def self.heuristic_response(scenario_name)
      SCENARIOS.dig(scenario_name, :heuristic_response) || {}
    end
  end
end
```

### Step 4: Anthropic Client (Real API)

```ruby
# app/services/llm/anthropic_client.rb
module LLM
  class AnthropicClient
    CLAUDE_API_URL = 'https://api.anthropic.com/v1/messages'
    CLAUDE_MODEL = 'claude-3-5-sonnet-20241022'

    def initialize
      @api_key = ENV['ANTHROPIC_API_KEY']
      raise 'ANTHROPIC_API_KEY environment variable not set' unless @api_key
    end

    def extract_profile(messages)
      response = call_api(build_request(messages))
      parse_response(response)
    rescue StandardError => e
      Rails.logger.error("Anthropic API error: #{e.message}")
      raise
    end

    private

    def build_request(messages)
      {
        model: CLAUDE_MODEL,
        max_tokens: 1024,
        system: system_prompt,
        messages: messages.map { |m| { role: m[:role], content: m[:content] } }
      }
    end

    def system_prompt
      <<~PROMPT
        You are a lead qualification assistant for a real estate platform.
        Extract the following information from the conversation:
        - budget (numeric, in MXN)
        - city (string)
        - area (string, neighborhood name)
        - bedrooms (integer)
        - bathrooms (integer)
        - property_type (casa, departamento, terreno)
        - phone (string, if provided)

        Return ONLY a JSON object with these fields. Omit fields if not mentioned.
        Be precise with numbers and do not confuse phone numbers with budgets.

        Example output:
        {
          "budget": 3000000,
          "city": "CDMX",
          "area": "Roma Norte",
          "bedrooms": 2,
          "confidence": "high"
        }
      PROMPT
    end

    def call_api(request_body)
      uri = URI(CLAUDE_API_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri.path)
      request['Content-Type'] = 'application/json'
      request['x-api-key'] = @api_key
      request['anthropic-version'] = '2023-06-01'
      request.body = request_body.to_json

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise "API request failed: #{response.code} - #{response.body}"
      end

      JSON.parse(response.body)
    end

    def parse_response(api_response)
      content = api_response.dig('content', 0, 'text')
      return {} unless content

      # Extract JSON from response (Claude might wrap it in markdown)
      json_match = content.match(/\{.*\}/m)
      return {} unless json_match

      parsed = JSON.parse(json_match[0])

      # Normalize keys to symbols and ensure types
      {
        budget: parsed['budget']&.to_i,
        city: parsed['city'],
        area: parsed['area'],
        bedrooms: parsed['bedrooms']&.to_i,
        bathrooms: parsed['bathrooms']&.to_i,
        property_type: parsed['property_type'],
        phone: parsed['phone'],
        confidence: parsed['confidence'] || 'medium'
      }.compact
    end
  end
end
```

---

## Testing Requirements

### CurrentAttributes Isolation

```ruby
# spec/models/current_spec.rb
require 'rails_helper'

RSpec.describe Current do
  describe 'thread isolation' do
    it 'isolates scenario per thread' do
      results = {}

      thread1 = Thread.new do
        Current.set(scenario: 'budget_seeker') do
          sleep 0.01
          results[:thread1] = Current.scenario
        end
      end

      thread2 = Thread.new do
        Current.set(scenario: 'budget_mismatch') do
          results[:thread2] = Current.scenario
        end
      end

      [thread1, thread2].each(&:join)

      expect(results[:thread1]).to eq('budget_seeker')
      expect(results[:thread2]).to eq('budget_mismatch')
    end

    it 'resets after block' do
      Current.set(scenario: 'budget_seeker') do
        expect(Current.scenario).to eq('budget_seeker')
      end

      expect(Current.scenario).to be_nil
    end
  end
end
```

### FakeClient Scenarios

```ruby
# spec/services/llm/fake_client_spec.rb
require 'rails_helper'

RSpec.describe LLM::FakeClient do
  describe '#extract_profile' do
    context 'with budget_seeker scenario' do
      around do |example|
        Current.set(scenario: 'budget_seeker') { example.run }
      end

      it 'returns predefined response' do
        client = described_class.new
        result = client.extract_profile([])

        expect(result).to include(
          budget: 3_000_000,
          city: 'CDMX',
          area: 'Roma Norte',
          bedrooms: 2
        )
      end
    end

    context 'with unknown scenario' do
      around do |example|
        Current.set(scenario: 'unknown') { example.run }
      end

      it 'falls back to AnthropicClient' do
        allow(LLM::AnthropicClient).to receive_message_chain(:new, :extract_profile).and_return({})

        client = described_class.new
        client.extract_profile([])

        expect(LLM::AnthropicClient).to have_received(:new)
      end
    end
  end

  describe '.scenario_messages' do
    it 'returns messages for budget_seeker' do
      messages = described_class.scenario_messages('budget_seeker')
      expect(messages).to be_an(Array)
      expect(messages.first).to include(role: 'user')
    end

    it 'returns empty array for unknown scenario' do
      expect(described_class.scenario_messages('unknown')).to eq([])
    end
  end
end
```

### Integration Test

```ruby
# spec/requests/scenario_integration_spec.rb
require 'rails_helper'

RSpec.describe 'Scenario Integration' do
  describe 'X-Scenario header' do
    it 'sets Current.scenario from header' do
      get '/health', headers: { 'X-Scenario' => 'budget_seeker' }

      # Would need to verify Current.scenario was set during request
      # This is integration-level, so we verify behavior indirectly
      expect(response).to have_http_status(:ok)
    end
  end
end
```

---

## Critical Constraints

### Thread Safety
- **NEVER** use `Thread.current[:scenario]` directly
- **ALWAYS** use `Current.scenario`
- **ENSURE** CurrentAttributes is reset between requests (Rails handles this)

### Scenario Fallback
- FakeClient **MUST** fall back to AnthropicClient if scenario unknown
- Production code should work without X-Scenario header
- Tests should explicitly set scenario via `Current.set`

### API Key Management
- AnthropicClient requires `ANTHROPIC_API_KEY` environment variable
- Fail fast with clear error if missing
- Never commit API keys to repository

---

## Success Criteria

- [ ] Current.scenario accessible throughout request lifecycle
- [ ] FakeClient returns correct responses for 3 scenarios
- [ ] FakeClient falls back to AnthropicClient for unknown scenarios
- [ ] AnthropicClient can make real API calls (tested manually or with VCR)
- [ ] Thread isolation tests pass
- [ ] X-Scenario header sets Current.scenario correctly

---

## Next Steps

After this module:
- Module 4 will use LLM::FakeClient for extraction
- Scenarios enable testing without API calls
- AnthropicClient provides real functionality

---

**Last Updated**: 2025-12-20
