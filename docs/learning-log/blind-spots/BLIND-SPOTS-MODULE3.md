# Blind Spots Analysis - Module 3: LLM Adapter

**Date**: 2025-12-26
**Module**: 03-llm-adapter
**Analyzer**: Claude Sonnet 4.5

---

## Analysis Summary

Comparing implemented code against `docs/ai-guidance/03-llm-adapter.md` and CLAUDE.md patterns.

---

## Issues Found

### 1. **Missing AnthropicClient Spec** ⚠️ IMPORTANT

**Severity**: IMPORTANT
**Location**: `spec/services/llm/anthropic_client_spec.rb` (MISSING)

**Issue**:
- No unit tests for `LLM::AnthropicClient`
- Guidance document doesn't explicitly require it, but it's a critical service
- Current coverage relies on integration tests via FakeClient fallback

**Impact**:
- Cannot verify AnthropicClient behavior in isolation
- No tests for error handling (API failures, malformed responses, timeouts)
- No tests for JSON extraction edge cases
- Would fail in production if API behavior changes

**Verification**:
```bash
ls spec/services/llm/anthropic_client_spec.rb
# ls: cannot access: No such file or directory
```

---

### 2. **Test Pattern Mismatch with Guidance** ⚠️ IMPORTANT

**Severity**: IMPORTANT
**Location**: `spec/models/current_spec.rb:22-62`, `spec/services/llm/fake_client_spec.rb`

**Issue**:
- Guidance uses `Current.set(scenario: 'value') { block }` pattern (lines 256-284)
- Implementation uses direct assignment `Current.scenario = 'value'` + `Current.reset`
- The `Current.set` block pattern is safer and auto-resets

**Actual Implementation**:
```ruby
# spec/models/current_spec.rb:69
Current.scenario = "first_request"
Current.reset
Current.scenario = "second_request"
```

**Guidance Pattern**:
```ruby
# 03-llm-adapter.md:256-260
Current.set(scenario: 'budget_seeker') do
  expect(Current.scenario).to eq('budget_seeker')
end
expect(Current.scenario).to be_nil  # Auto-reset
```

**Impact**:
- Tests pass but don't follow Rails best practices
- Manual reset is error-prone (easy to forget)
- Could leak state between tests if reset is missed

**Why This Happened**:
- `Current.set` with block wasn't obvious from Step 1 example
- Direct attribute access worked fine for simple cases
- Integration tests passed without needing block pattern

---

### 3. **Host Authorization Configuration Not in Guidance** ℹ️ OPTIONAL

**Severity**: OPTIONAL
**Location**: `config/environments/test.rb:20-23`

**Issue**:
- Had to add custom host authorization config for request specs
- Not documented in guidance or CLAUDE.md
- Rails 7.2 default behavior blocks test requests

**Added Configuration**:
```ruby
config.hosts << "www.example.com"
config.hosts << ".example.com"
config.hosts << "localhost"
```

**Impact**:
- Without this, all request specs fail with 403 Forbidden
- Future modules might hit same issue
- Should be documented in foundation guidance

---

### 4. **LLM Acronym Inflector Not in Guidance** ℹ️ OPTIONAL

**Severity**: OPTIONAL
**Location**: `config/application.rb:43-46`

**Issue**:
- Zeitwerk requires inflector configuration for `LLM` acronym
- Not mentioned in Module 3 guidance
- Caused "uninitialized constant LLM" errors initially

**Added Configuration**:
```ruby
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym "LLM"
end
```

**Impact**:
- Without this, module namespace doesn't load
- Common Rails gotcha for acronyms (API, URL, LLM, etc.)
- Should be in guidance or foundation setup

---

### 5. **No VCR/WebMock for AnthropicClient** ℹ️ OPTIONAL

**Severity**: OPTIONAL
**Location**: `spec/services/llm/anthropic_client_spec.rb` (would be here)

**Issue**:
- Guidance mentions "tested manually or with VCR" (line 389)
- No VCR cassettes or WebMock stubs implemented
- Tests rely entirely on mocking `AnthropicClient.new`

**Impact**:
- Can't verify real API integration behavior
- Can't test against recorded API responses
- Manual testing required for API changes

**Note**: This is acceptable for demo scope per ADR-001, but would be required for production.

---

### 6. **No Spec for AnthropicClient Error Scenarios** ⚠️ IMPORTANT

**Severity**: IMPORTANT
**Location**: `spec/services/llm/anthropic_client_spec.rb` (MISSING)

**Issue**:
- No tests for API timeout (http.read_timeout = 30)
- No tests for malformed JSON responses
- No tests for API rate limiting (429)
- No tests for API errors (500, 503)
- No tests for missing environment variable

**Missing Test Cases**:
```ruby
# Should test but doesn't:
- ANTHROPIC_API_KEY not set → raises clear error
- API returns 500 → raises with message
- API returns invalid JSON → returns {}
- API timeout after 30s → raises StandardError
- Response missing 'content' key → returns {}
- Response has JSON wrapped in markdown code blocks
```

**Impact**:
- Production failures wouldn't be caught in tests
- Error messages might be unclear
- Timeout behavior untested

---

## Non-Issues (False Alarms)

### Thread Isolation Tests
- ✅ Implemented correctly in `spec/models/current_spec.rb:22-50`
- ✅ Tests concurrent access (10 threads)
- ✅ Tests parent/child isolation

### Scenario Fallback
- ✅ FakeClient correctly falls back to AnthropicClient
- ✅ Tested in `spec/services/llm/fake_client_spec.rb:73-105`

### Structured Logging
- ✅ ApplicationController logs scenario when present
- ✅ Tested in `spec/requests/scenario_integration_spec.rb:43-58`

---

## Summary Statistics

| Severity   | Count | Issues                                        |
|------------|-------|-----------------------------------------------|
| CRITICAL   | 0     | -                                             |
| IMPORTANT  | 3     | Missing AnthropicClient spec, Test pattern, Error scenarios |
| OPTIONAL   | 3     | Host config, LLM inflector, VCR             |
| **TOTAL**  | **6** |                                               |

---

## Recommended Actions

### Must Fix (IMPORTANT)
1. Add `spec/services/llm/anthropic_client_spec.rb` with error handling tests
2. Consider refactoring tests to use `Current.set { block }` pattern
3. Document error scenarios for AnthropicClient

### Should Document (OPTIONAL)
4. Add host authorization config to foundation guidance
5. Add LLM inflector to foundation or Module 3 guidance
6. Document VCR as optional for production (not needed for demo)

---

## Lessons Learned

1. **Guidance completeness**: Examples should show Rails best practices (Current.set with block)
2. **Rails 7.2 gotchas**: Host authorization and Zeitwerk acronyms should be documented upfront
3. **Error testing**: Complex external services need comprehensive error scenario tests
4. **Test coverage gaps**: Integration tests passing doesn't mean unit tests are complete

---

**Next Steps**: Create `module3-fixes.md` with actionable checklist for IMPORTANT items.
