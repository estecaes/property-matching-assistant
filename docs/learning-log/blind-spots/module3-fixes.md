# Module 3 Fixes Checklist

**Created**: 2025-12-26
**Based on**: BLIND-SPOTS-MODULE3.md

---

## IMPORTANT Fixes (Required)

### 1. Add AnthropicClient Unit Tests ✅ COMPLETED
- [x] **Create** `spec/services/llm/anthropic_client_spec.rb`
- [x] Test missing ANTHROPIC_API_KEY raises clear error
- [x] Test successful API call with valid response
- [x] Test API errors (500, 503) raise with message
- [x] Test timeout behavior (30s)
- [x] Test malformed JSON response returns {}
- [x] Test missing 'content' key returns {}
- [x] Test JSON extraction with markdown code blocks
- [x] Test rate limiting (429) handling

**Completed in**: Commit 1c5071e
**Result**: 24 examples passing

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

### 2. Document Error Scenarios ✅ COMPLETED
- [x] **Add** error handling documentation to AnthropicClient class
- [x] Document expected behavior for each error type
- [x] Add examples of error responses

**Completed in**: Commit 5eaa2a9
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

### 3. Evaluate Test Pattern Refactor ✅ COMPLETED
- [x] **Review** Current.set block pattern vs direct assignment
- [x] **Decide** if worth refactoring or documenting as-is
- [x] **Document** decision in ADR-003 or module3-fixes.md

**Completed in**: Commit 43390cb
**Decision**: Added automatic cleanup with `after { Current.reset }` hooks instead of full refactor to block pattern

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

### 4. Document Host Authorization Config ✅ COMPLETED
- [x] **Add** to Module 1 guidance or CLAUDE.md
- [x] Note Rails 7.2 requires explicit host allowlist
- [x] Include test environment configuration

**Completed in**: Commit 42aa071
**Location**: `docs/ai-guidance/01-foundation.md`

---

### 5. Document LLM Inflector Setup ✅ COMPLETED
- [x] **Add** to Module 3 guidance Step 0 (Prerequisites)
- [x] Explain Zeitwerk acronym handling
- [x] Reference Rails guides on inflections

**Completed in**: Commit 42aa071
**Location**: `docs/ai-guidance/03-llm-adapter.md:23-45` (new Step 0)

---

### 6. VCR Setup ✅ COMPLETED (FULLY IMPLEMENTED)
- [x] **Add** VCR gem to Gemfile
- [x] **Create** spec/support/vcr.rb with security filters
- [x] **Add** VCR integration tests for AnthropicClient
- [x] **Create** mock cassettes for test scenarios
- [x] **Update** docker-compose.yml for CI/CD compatibility
- [x] **Verify** no API keys in cassettes

**Completed in**: Commit 275721b
**Result**: 4 new VCR tests, 114 total examples passing

**Decision Change**: Initially planned to skip VCR for demo scope, but user had API key available and requested full implementation. This provides production-quality testing without API costs in CI/CD.

**Implementation**:
```ruby
# spec/support/vcr.rb
VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock

  # SECURITY: Filter sensitive data
  config.filter_sensitive_data("<ANTHROPIC_API_KEY>") { ENV["ANTHROPIC_API_KEY"] }
  config.filter_sensitive_data("<X-API-KEY-HEADER>") do |interaction|
    interaction.request.headers["X-Api-Key"]&.first
  end
end
```

**Cassettes Created**:
- `extract_simple_profile.yml` - Simple budget extraction
- `extract_complex_profile.yml` - Multi-field extraction
- `phone_vs_budget.yml` - Phone number vs budget distinction
- `markdown_wrapped_json.yml` - JSON in markdown code blocks

**CI/CD Support**:
```yaml
# docker-compose.yml
environment:
  ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY:-dummy-key-for-vcr}
  # All variables now have fallback values
  # No .env file required for CI/CD
```

**Security Verification**:
```bash
grep -r "sk-ant" spec/fixtures/vcr_cassettes/
# ✓ No API keys found - all filtered
```

---

## Summary

| Priority   | Tasks | Status     | Commits                                    |
|------------|-------|------------|--------------------------------------------|
| IMPORTANT  | 3     | ✅ DONE    | 1c5071e, 5eaa2a9, 43390cb                 |
| OPTIONAL   | 3     | ✅ DONE    | 42aa071 (4+5), 275721b (6 - IMPLEMENTED)  |
| **TOTAL**  | **6** | **100%**   | **6 commits**                              |

---

## Completion Report

**All Module 3 fixes completed successfully!**

### IMPORTANT Fixes:
1. ✅ AnthropicClient unit tests (24 examples) - Commit 1c5071e
2. ✅ Error handling documentation - Commit 5eaa2a9
3. ✅ Automatic Current.reset cleanup - Commit 43390cb

### OPTIONAL Fixes:
4. ✅ Host authorization documentation - Commit 42aa071
5. ✅ LLM inflector documentation - Commit 42aa071
6. ✅ **VCR full implementation** - Commit 275721b (not just documented!)

### Final Test Results:
- **114 examples, 0 failures** (110 previous + 4 VCR tests)
- All Module 2 + Module 3 tests passing
- No state leakage between tests
- Comprehensive error scenario coverage
- VCR cassettes secure (API keys filtered)
- CI/CD compatible (no .env required)

---

**Ready for Module 4**: All blind spots addressed. Foundation is solid for LeadQualifier implementation.
