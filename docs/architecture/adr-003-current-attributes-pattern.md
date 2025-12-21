# ADR-003: CurrentAttributes for Scenario Context Management

**Status**: Active
**Date**: 2025-12-20
**Context**: Thread-safe scenario management for demo testing

---

## Context

The demo needs to support **3 test scenarios** (budget_seeker, budget_mismatch, phone_vs_budget) that simulate different lead qualification flows. Each scenario requires:
- Predefined conversation messages
- Expected extraction results
- Specific LLM responses (without actual API calls in tests)

We need a way to:
1. Switch between scenarios via HTTP header (`X-Scenario`)
2. Maintain scenario context through request lifecycle
3. Ensure thread safety in multi-request environments
4. Avoid global state pollution

---

## Decision

Use **`ActiveSupport::CurrentAttributes`** for scenario context management.

### Implementation Pattern

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :scenario
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  before_action :set_scenario

  private

  def set_scenario
    Current.scenario = request.headers['X-Scenario']
  end
end

# app/services/llm/fake_client.rb
module LLM
  class FakeClient
    SCENARIOS = {
      'budget_seeker' => {
        messages: [...],
        llm_response: {...}
      },
      'budget_mismatch' => {
        messages: [...],
        llm_response: {...}
      },
      'phone_vs_budget' => {
        messages: [...],
        llm_response: {...}
      }
    }.freeze

    def extract_profile(messages)
      scenario_data = SCENARIOS[Current.scenario]
      return scenario_data[:llm_response] if scenario_data

      # Fallback to real Anthropic API
      LLM::AnthropicClient.new.extract_profile(messages)
    end
  end
end
```

---

## Alternatives Considered

### 1. Thread.current (Global State)
```ruby
Thread.current[:scenario] = 'budget_seeker'
```

**Rejected because**:
❌ Not Rails-aware, doesn't reset between requests
❌ Potential memory leaks in thread pools
❌ No automatic cleanup
❌ Violates Rails conventions

### 2. Request Parameters
```ruby
# POST /run?scenario=budget_seeker
params[:scenario]
```

**Rejected because**:
❌ Couples API design to testing needs
❌ Scenarios would be exposed in production API
❌ URL pollution for internal testing concern
❌ Harder to toggle on/off in production

### 3. Environment Variables
```ruby
ENV['SCENARIO'] = 'budget_seeker'
```

**Rejected because**:
❌ Global state, not request-scoped
❌ Can't handle concurrent requests with different scenarios
❌ Requires process restart to change
❌ Not suitable for multi-tenant testing

### 4. Dependency Injection
```ruby
LeadQualifier.new(scenario: 'budget_seeker').call(session)
```

**Rejected because**:
❌ Passes scenario through entire call stack
❌ Pollutes service object signatures
❌ Makes production code aware of test concerns
❌ More complex than needed for demo scope

---

## Consequences

### Positive
✅ **Thread-safe**: Isolated per request in Rails
✅ **Automatic cleanup**: Resets after each request
✅ **Rails convention**: Official pattern for request-scoped state
✅ **Clean separation**: Scenario logic in FakeClient only
✅ **Header-based**: Clean API, easy to test with curl

### Negative
⚠️ **Rails-specific**: Wouldn't work in plain Ruby
⚠️ **Hidden context**: State not visible in method signatures
⚠️ **Testing complexity**: Must set Current.scenario in tests

### Mitigations
- **Documentation**: Clear comments in code about CurrentAttributes usage
- **Test helpers**: RSpec shared context for scenario setup
- **Production safety**: FakeClient checks scenario, falls back to real API

---

## Usage Examples

### Via HTTP Header
```bash
curl -X POST http://localhost:3000/run \
  -H "X-Scenario: budget_mismatch" \
  -H "Content-Type: application/json"
```

### In RSpec Tests
```ruby
RSpec.describe LeadQualifier do
  around do |example|
    Current.set(scenario: 'budget_mismatch') do
      example.run
    end
  end

  it 'detects discrepancies' do
    # Current.scenario is 'budget_mismatch' within this block
    result = LeadQualifier.call(session)
    expect(result.discrepancies).not_to be_empty
  end
end
```

### In Controllers
```ruby
class RunsController < ApplicationController
  def create
    # Current.scenario already set by before_action
    session = ConversationSession.create!
    LeadQualifier.call(session)  # Uses Current.scenario internally
    PropertyMatcher.call(session.lead_profile)

    render json: session
  end
end
```

---

## Thread Safety Considerations

### How CurrentAttributes Works
```ruby
# Rails request lifecycle
1. Request starts
2. before_action sets Current.scenario = 'budget_seeker'
3. Controller/service code reads Current.scenario
4. Request ends
5. CurrentAttributes automatically resets to nil
```

### Thread Isolation
- Each Rails request runs in its own thread (or fiber with async)
- CurrentAttributes uses `Thread.current` internally BUT with Rails lifecycle hooks
- Automatic cleanup prevents leakage between requests

### Production Safety
```ruby
# In production, if X-Scenario header is absent:
Current.scenario #=> nil

# FakeClient behavior:
def extract_profile(messages)
  return SCENARIOS[Current.scenario][:llm_response] if Current.scenario

  # Falls back to real API when scenario is nil
  LLM::AnthropicClient.new.extract_profile(messages)
end
```

---

## Testing Strategy

### Unit Tests
```ruby
# spec/models/current_spec.rb
RSpec.describe Current do
  it 'isolates scenario per thread' do
    thread1_value = nil
    thread2_value = nil

    thread1 = Thread.new do
      Current.set(scenario: 'budget_seeker') do
        sleep 0.01
        thread1_value = Current.scenario
      end
    end

    thread2 = Thread.new do
      Current.set(scenario: 'budget_mismatch') do
        thread2_value = Current.scenario
      end
    end

    thread1.join
    thread2.join

    expect(thread1_value).to eq('budget_seeker')
    expect(thread2_value).to eq('budget_mismatch')
  end
end
```

### Integration Tests
```ruby
# spec/requests/scenarios_spec.rb
RSpec.describe 'Scenario Management' do
  it 'uses correct scenario from header' do
    post '/run', headers: { 'X-Scenario' => 'budget_mismatch' }

    json = JSON.parse(response.body)
    expect(json['discrepancies']).not_to be_empty
  end

  it 'falls back to real API when header missing' do
    # Would need VCR cassette or mocked Anthropic client
    post '/run'

    expect(response).to have_http_status(:ok)
  end
end
```

---

## Production Considerations

### If Scaling to Production

**Remove scenario management entirely**:
```ruby
# Keep CurrentAttributes for other uses (current_user, request_id)
# but remove scenario logic

class Current < ActiveSupport::CurrentAttributes
  attribute :request_id
  attribute :user
  # Remove: attribute :scenario
end
```

**Use feature flags instead**:
```ruby
# For A/B testing or gradual rollouts
if Flipper.enabled?(:new_extraction_algorithm, current_user)
  NewLeadQualifier.call(session)
else
  LeadQualifier.call(session)
end
```

**Real LLM client only**:
```ruby
# Remove FakeClient entirely
# Use VCR for test recording, not fake responses
```

---

## EasyBroker Alignment

### Rails Conventions
CurrentAttributes is official Rails pattern, aligns with "Rails way" philosophy.

### Clean Code
- Single responsibility: Current handles context, services handle logic
- No global pollution: Request-scoped, automatic cleanup
- Testable: Easy to set in tests, isolated per thread

### POODR
- Prefer composition over callbacks
- Explicit dependencies (services can access Current.scenario)
- No hidden coupling (documented usage)

---

## References

- Rails Guides: https://api.rubyonrails.org/classes/ActiveSupport/CurrentAttributes.html
- DHH on CurrentAttributes: https://dhh.dk/2017/current-attributes.html
- Thread safety: https://guides.rubyonrails.org/threading_and_code_execution.html
- Blueprint: Module 3 - LLM Adapter

---

**Review Trigger**: After Module 3 completion
**Owner**: Project lead
**Last Updated**: 2025-12-20
