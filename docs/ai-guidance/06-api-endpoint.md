# Módulo 6: API Endpoint - AI Guidance

**Estimated Time**: 1.5 hours
**Status**: Pending
**Dependencies**: Module 4 (LeadQualifier), Module 5 (PropertyMatcher)

---

## Objectives

1. Implement POST /run endpoint
2. Create ConversationSession with scenario messages
3. Call LeadQualifier and PropertyMatcher
4. Return structured JSON response
5. Handle errors gracefully

---

## Implementation

### Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  get '/health', to: 'health#show'
  post '/run', to: 'runs#create'
end
```

### Controller

```ruby
# app/controllers/runs_controller.rb
class RunsController < ApplicationController
  def create
    session = create_session_with_messages
    qualify_lead(session)
    matches = match_properties(session)

    render json: format_response(session, matches), status: :ok
  rescue StandardError => e
    handle_error(e)
  end

  private

  def create_session_with_messages
    session = ConversationSession.create!

    messages = if Current.scenario
                 LLM::FakeClient.scenario_messages(Current.scenario)
               else
                 # In production, messages would come from request body
                 []
               end

    messages.each_with_index do |msg, index|
      session.messages.create!(
        role: msg[:role],
        content: msg[:content],
        sequence_number: index
      )
    end

    session.update!(turns_count: messages.size)
    session
  end

  def qualify_lead(session)
    LeadQualifier.call(session)
  end

  def match_properties(session)
    return [] unless session.city_present?

    PropertyMatcher.call(session.lead_profile)
  end

  def format_response(session, matches)
    {
      session_id: session.id,
      lead_profile: session.lead_profile,
      matches: matches,
      needs_human_review: session.needs_human_review,
      discrepancies: session.discrepancies,
      metrics: {
        qualification_duration_ms: session.qualification_duration_ms,
        turns_count: session.turns_count
      },
      status: session.status
    }
  end

  def handle_error(error)
    Rails.logger.error({
      event: 'run_error',
      error_class: error.class.name,
      error_message: error.message,
      backtrace: error.backtrace.first(5)
    }.to_json)

    render json: {
      error: 'Internal server error',
      message: error.message
    }, status: :internal_server_error
  end
end
```

---

## Response Structure

### Success Response (budget_seeker)

```json
{
  "session_id": 1,
  "lead_profile": {
    "budget": 3000000,
    "city": "CDMX",
    "area": "Roma Norte",
    "bedrooms": 2,
    "confidence": "high"
  },
  "matches": [
    {
      "id": 5,
      "title": "Departamento en Roma Norte",
      "price": 2950000.0,
      "city": "CDMX",
      "area": "Roma Norte",
      "bedrooms": 2,
      "bathrooms": 2,
      "score": 90,
      "reasons": [
        "budget_exact_match",
        "bedrooms_exact_match",
        "area_exact_match"
      ]
    },
    {
      "id": 7,
      "title": "Departamento en Roma Norte",
      "price": 3100000.0,
      "city": "CDMX",
      "area": "Roma Norte",
      "bedrooms": 2,
      "bathrooms": 2,
      "score": 90,
      "reasons": [
        "budget_exact_match",
        "bedrooms_exact_match",
        "area_exact_match"
      ]
    }
  ],
  "needs_human_review": false,
  "discrepancies": [],
  "metrics": {
    "qualification_duration_ms": 145,
    "turns_count": 5
  },
  "status": "qualified"
}
```

### Success Response with Discrepancies (budget_mismatch)

```json
{
  "session_id": 2,
  "lead_profile": {
    "budget": 3000000,
    "city": "Guadalajara",
    "confidence": "medium"
  },
  "matches": [],
  "needs_human_review": true,
  "discrepancies": [
    {
      "field": "budget",
      "llm_value": 5000000,
      "heuristic_value": 3000000,
      "diff_pct": 66.7,
      "severity": "high"
    }
  ],
  "metrics": {
    "qualification_duration_ms": 234,
    "turns_count": 3
  },
  "status": "qualified"
}
```

### Error Response

```json
{
  "error": "Internal server error",
  "message": "Validation failed: City can't be blank"
}
```

---

## Testing Requirements

### Request Specs

```ruby
# spec/requests/runs_spec.rb
require 'rails_helper'

RSpec.describe 'POST /run', type: :request do
  context 'with budget_seeker scenario' do
    it 'returns successful qualification with matches' do
      post '/run', headers: { 'X-Scenario' => 'budget_seeker' }

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['session_id']).to be_present
      expect(json['lead_profile']['budget']).to eq(3_000_000)
      expect(json['lead_profile']['city']).to eq('CDMX')
      expect(json['matches']).not_to be_empty
      expect(json['needs_human_review']).to be false
      expect(json['discrepancies']).to be_empty
      expect(json['metrics']['qualification_duration_ms']).to be > 0
    end
  end

  context 'with budget_mismatch scenario' do
    it 'returns discrepancies and needs_human_review' do
      post '/run', headers: { 'X-Scenario' => 'budget_mismatch' }

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['needs_human_review']).to be true
      expect(json['discrepancies']).not_to be_empty

      budget_disc = json['discrepancies'].find { |d| d['field'] == 'budget' }
      expect(budget_disc).to be_present
      expect(budget_disc['diff_pct']).to be > 20
    end
  end

  context 'with phone_vs_budget scenario' do
    it 'correctly extracts budget, not phone' do
      post '/run', headers: { 'X-Scenario' => 'phone_vs_budget' }

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['lead_profile']['budget']).to eq(3_000_000)
      expect(json['lead_profile']['budget']).not_to eq(5_512_345_678)
    end
  end

  context 'without scenario header' do
    it 'returns error or empty response' do
      # This would hit real API or fail gracefully
      post '/run'

      # Depends on implementation:
      # Either returns error because no messages provided
      # Or falls back to AnthropicClient
      expect(response).to have_http_status(:ok).or have_http_status(:unprocessable_entity)
    end
  end

  context 'when errors occur' do
    before do
      allow(LeadQualifier).to receive(:call).and_raise(StandardError, 'Test error')
    end

    it 'returns error response' do
      post '/run', headers: { 'X-Scenario' => 'budget_seeker' }

      expect(response).to have_http_status(:internal_server_error)

      json = JSON.parse(response.body)
      expect(json['error']).to eq('Internal server error')
      expect(json['message']).to eq('Test error')
    end
  end
end
```

---

## Critical Constraints

### Error Handling
- Catch all errors at controller level
- Log errors with structured JSON
- Return friendly error messages (don't expose internals)
- Use appropriate HTTP status codes

### Response Structure
- Consistent JSON structure across all scenarios
- Include metrics for observability
- discrepancies[] always present (even if empty)
- matches[] always present (even if empty)

### Scenario Management
- X-Scenario header optional (production won't use it)
- Graceful fallback when header missing
- Create messages from scenario or request body

---

## Success Criteria

- [ ] POST /run works for all 3 scenarios
- [ ] Response includes all required fields
- [ ] Error handling returns 500 with message
- [ ] Logs are structured JSON
- [ ] Tests cover happy path and error cases

---

**Last Updated**: 2025-12-20
