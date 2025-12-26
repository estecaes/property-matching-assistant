# Module 3 Fixes Checklist

**Created**: 2025-12-26
**Based on**: BLIND-SPOTS-MODULE3.md

---

## IMPORTANT Fixes (Required)

### 1. Add AnthropicClient Unit Tests
- [ ] **Create** `spec/services/llm/anthropic_client_spec.rb`
- [ ] Test missing ANTHROPIC_API_KEY raises clear error
- [ ] Test successful API call with valid response
- [ ] Test API errors (500, 503) raise with message
- [ ] Test timeout behavior (30s)
- [ ] Test malformed JSON response returns {}
- [ ] Test missing 'content' key returns {}
- [ ] Test JSON extraction with markdown code blocks
- [ ] Test rate limiting (429) handling

**Estimated Time**: 30 minutes

**Example Test Structure**:
```ruby
RSpec.describe LLM::AnthropicClient do
  describe '#initialize' do
    context 'when ANTHROPIC_API_KEY is not set' do
      it 'raises error with clear message'
    end
  end

  describe '#extract_profile' do
    context 'with successful API response' do
      it 'parses JSON and returns profile hash'
    end

    context 'when API returns 500' do
      it 'logs error and raises StandardError'
    end

    context 'when response is malformed' do
      it 'returns empty hash'
    end

    context 'when request times out' do
      it 'raises timeout error'
    end
  end
end
```

**Verification**:
```bash
docker compose run --rm app rspec spec/services/llm/anthropic_client_spec.rb
```

---

### 2. Document Error Scenarios
- [ ] **Add** error handling documentation to AnthropicClient class
- [ ] Document expected behavior for each error type
- [ ] Add examples of error responses

**Location**: `app/services/llm/anthropic_client.rb`

**Example Addition**:
```ruby
# Error Handling:
# - Missing API key: Raises on initialization
# - API errors (500, 503): Logs and raises StandardError
# - Timeout (>30s): Raises Net::ReadTimeout
# - Malformed JSON: Returns empty hash {}
# - Missing content: Returns empty hash {}
```

---

### 3. Evaluate Test Pattern Refactor
- [ ] **Review** Current.set block pattern vs direct assignment
- [ ] **Decide** if worth refactoring or documenting as-is
- [ ] **Document** decision in ADR-003 or module3-fixes.md

**Current Pattern** (works but manual):
```ruby
Current.scenario = "budget_seeker"
# ... tests ...
Current.reset
```

**Rails Best Practice** (auto-reset):
```ruby
Current.set(scenario: "budget_seeker") do
  # ... tests ...
end
# Automatically reset
```

**Decision Criteria**:
- Low priority if tests pass reliably
- Consider for Module 4+ if state leakage becomes issue
- Not blocking for demo scope

---

## OPTIONAL Improvements (Nice-to-Have)

### 4. Document Host Authorization Config
- [ ] **Add** to Module 1 guidance or CLAUDE.md
- [ ] Note Rails 7.2 requires explicit host allowlist
- [ ] Include test environment configuration

**Location**: `docs/ai-guidance/01-foundation.md` or CLAUDE.md Testing section

---

### 5. Document LLM Inflector Setup
- [ ] **Add** to Module 3 guidance Step 0 (Prerequisites)
- [ ] Explain Zeitwerk acronym handling
- [ ] Reference Rails guides on inflections

**Location**: `docs/ai-guidance/03-llm-adapter.md:22` (before Step 1)

---

### 6. VCR Setup (Production Only)
- [x] **Skip** for demo scope per ADR-001
- [x] Document as production requirement
- [x] Add note to module3-fixes.md

**Note**: Not needed for 6-8 hour demo. Would add 1-2 hours setup time.

**Production Recommendation**: For production deployment, add VCR gem to record and replay HTTP interactions with Anthropic API. This provides:
- Deterministic API testing without live requests
- Protection against API changes breaking tests
- Faster test suite execution
- No API costs during CI/CD runs

**Implementation** (when needed):
```ruby
# Gemfile
gem 'vcr', group: :test
gem 'webmock', group: :test  # Already added

# spec/support/vcr.rb
VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data('<ANTHROPIC_API_KEY>') { ENV['ANTHROPIC_API_KEY'] }
end

# Usage in specs
it "extracts profile from real API" do
  VCR.use_cassette("anthropic/extract_profile") do
    # Real API call gets recorded on first run
    # Replayed from cassette on subsequent runs
  end
end
```

---

## Summary

| Priority   | Tasks | Estimated Time |
|------------|-------|----------------|
| IMPORTANT  | 3     | 45 min         |
| OPTIONAL   | 3     | 30 min         |
| **TOTAL**  | **6** | **75 min**     |

---

## Recommendation

**For immediate Module 4 start**:
- Fix #1 (AnthropicClient tests) - **REQUIRED**
- Fix #2 (Error documentation) - **QUICK WIN**
- Defer #3 (pattern refactor) - **NOT BLOCKING**
- Defer #4-6 (documentation) - **OPTIONAL**

**Rationale**: Module 4 (LeadQualifier) will heavily use LLM clients. Having solid AnthropicClient tests ensures the foundation is reliable before building anti-injection logic on top.

---

**Next Action**: Execute Fix #1 and #2, then proceed to Module 4.
