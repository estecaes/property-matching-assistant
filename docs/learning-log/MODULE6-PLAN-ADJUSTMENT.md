# Module 6 Plan Adjustment Based on Blind Spots Analysis

**Date**: 2025-12-27
**Module**: 06-api-endpoint (POST /run)
**Status**: Plan adjusted before implementation

---

## Purpose

Before implementing Module 6, reviewed ALL blind spots from previous modules (2-5) to identify patterns and adjust the implementation approach proactively.

---

## Blind Spots Review Summary

### Module 2 Blind Spots (10 identified)
- ✅ JSONB array initialization (`discrepancies` must be `[]`)
- ✅ String vs symbol keys handling
- ⚠️ Host authorization for request specs (unresolved at that time)

### Module 3 Blind Spots (6 identified)
- 🔴 **CRITICAL**: Host Authorization configuration required in test environment
  - **Issue**: Rails 7.2 blocks `www.example.com` by default in test mode
  - **Solution**: Add hosts to `config/environments/test.rb`
  - **Pattern established**: Use `host! 'localhost'` in request specs

### Module 4 Blind Spots (4 identified)
- 🔴 VCR integration tests missing (added separately)
- 🔴 Duration validation edge case (0ms → min 1ms)
- 🔴 Severity threshold calibration (>30% not >50%)
- 🟡 Budget extraction strategy evolution

### Module 5 Blind Spots (3 identified)
- 🔴 Budget zero division error (`.zero?` check)
- 🔴 String keys untested (production JSON format)
- 🟡 Missing structured logging

---

## Module 6 Plan Adjustments

### ORIGINAL Plan (from docs/ai-guidance/06-api-endpoint.md)

```markdown
1. Implement POST /run endpoint
2. Create ConversationSession with scenario messages
3. Call LeadQualifier and PropertyMatcher
4. Return structured JSON response
5. Handle errors gracefully
```

**Testing approach**: Write tests after implementation (implied)

### ADJUSTED Plan (Based on Blind Spots)

#### 1. Pre-Implementation Checklist

**BEFORE writing any code:**

- [x] **Review Module 3 HostAuthorization lesson** (blind spot #3)
  - Solution: Use `host! 'localhost'` in request specs
  - Pattern already established in `spec/requests/health_spec.rb`
  - **Action**: Check existing request specs for pattern before starting

- [x] **Review Module 4 error handling patterns** (blind spot #1)
  - Structured JSON logging for errors
  - Graceful LLM failure handling
  - **Action**: Replicate error handling pattern in RunsController

- [x] **Review Module 5 string keys handling** (blind spot #2)
  - Production will send string keys from JSON
  - PropertyMatcher already handles with `.symbolize_keys`
  - **Action**: No changes needed, but verify in integration tests

#### 2. Implementation Strategy

**TDD Approach with Pattern Reuse:**

1. **Routes** - Add POST /run
2. **Controller skeleton** - Thin controller, delegate to services
3. **Tests FIRST** - Write request specs following health_spec pattern
   - ✅ Use `host! 'localhost'` (Module 3 lesson)
   - ✅ Test all scenarios (budget_seeker, budget_mismatch, phone_vs_budget)
   - ✅ Test error scenarios (Module 4 lesson)
   - ✅ Test response structure validation
4. **Implement controller methods** - Make tests pass
5. **Verify integration** - Run full test suite

#### 3. Critical Patterns to Apply

**From Module 3** (HostAuthorization):
```ruby
# spec/requests/runs_spec.rb
RSpec.describe 'POST /run', type: :request do
  before do
    host! 'localhost'  # ✅ CRITICAL - prevents 403 Forbidden
  end
  # ...
end
```

**From Module 4** (Error Handling):
```ruby
# app/controllers/runs_controller.rb
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
```

**From Module 5** (String Keys):
```ruby
# Already handled by PropertyMatcher
# No action needed, but verify in tests
```

#### 4. Testing Requirements (Enhanced)

**Original requirements:**
- ✅ POST /run works for all 3 scenarios
- ✅ Response includes all required fields
- ✅ Error handling returns 500 with message
- ✅ Logs are structured JSON

**Added requirements from blind spots:**
- ✅ Use `host! 'localhost'` to prevent HostAuthorization errors
- ✅ Test error logging structure (not just response)
- ✅ Test response structure validation (all required keys present)
- ✅ Test missing scenario header (graceful fallback)

---

## Blind Spot That WAS Encountered

### 🔴 BLIND SPOT #1: HostAuthorization Pattern Not Applied

**Issue**: Implemented request specs WITHOUT reviewing existing request spec patterns

**What happened:**
1. Wrote `spec/requests/runs_spec.rb` without `host! 'localhost'`
2. All tests failed with 403 Forbidden
3. Attempted to fix in `config/environments/test.rb` with `config.hosts.clear`
4. Restarted containers - still failed
5. **Finally discovered**: `spec/requests/health_spec.rb` already had the solution

**Root cause:**
- Did NOT review existing request specs before writing new ones
- Ignored Module 3 blind spot lesson about HostAuthorization
- Tried to fix configuration instead of following established pattern

**Discovery method:**
- User intervention: "Review blind spots before proceeding"
- Forced review revealed the pattern in `health_spec.rb`

**Fix applied:**
```ruby
# spec/requests/runs_spec.rb
before do
  host! 'localhost'  # ✅ Following health_spec.rb pattern
end
```

**Time lost**: ~30 minutes (multiple failed test runs + container restarts)

**Prevention**: ✅ **ALWAYS review existing spec files for patterns before writing new specs**

---

## Lessons Learned for Module 6

### ✅ What Worked

1. **Reviewing blind spots BEFORE implementation**
   - Caught HostAuthorization issue in review (but didn't apply it initially)
   - Identified error handling patterns to replicate

2. **User intervention at right time**
   - Stopped me before committing flawed implementation
   - Forced proper blind spot review and pattern analysis

3. **Existing patterns as guide**
   - `health_spec.rb` had the solution all along
   - Following established patterns is faster than fixing configuration

### 🔍 What Was Missed (Initially)

1. **Did not check existing request specs FIRST**
   - Should have read `health_spec.rb` before writing `runs_spec.rb`
   - Pattern was already established in codebase

2. **Attempted config fix instead of pattern reuse**
   - Tried `config.hosts.clear` instead of `host! 'localhost'`
   - Over-engineered the solution

### 📚 Prevention Strategy Going Forward

1. **ALWAYS review similar existing files before implementing**
   - Before writing a request spec → read existing request specs
   - Before writing a service → read existing services
   - Before writing a controller → read existing controllers

2. **Trust established patterns over configuration changes**
   - If a pattern exists in the codebase, use it
   - Don't try to "fix" things at configuration level first

3. **Blind spot reviews must be ACTIONABLE**
   - Not just "read blind spots" but "apply blind spot lessons"
   - Create checklist of patterns to follow

---

## Final Adjusted Plan (Implemented)

### Implementation Steps Taken

1. ✅ Review routes configuration
2. ✅ Create RunsController with create action
3. ✅ Implement private methods:
   - `create_session_with_messages` - scenario-based message creation
   - `qualify_lead` - delegate to LeadQualifier
   - `match_properties` - delegate to PropertyMatcher with city check
   - `format_response` - complete JSON structure
   - `handle_error` - structured logging + error response
4. ✅ Write request specs with `host! 'localhost'` (Module 3 pattern)
5. ✅ Fix HostAuthorization issue by applying established pattern
6. ✅ Run full test suite: **167 examples, 0 failures**

### Test Coverage Added

- 12 request spec examples
- All scenarios covered (budget_seeker, budget_mismatch, phone_vs_budget, missing_city)
- Error handling tested
- Response structure validation tested

---

## Success Criteria

- [x] POST /run works for all scenarios
- [x] Response includes all required fields
- [x] Error handling returns 500 with structured logging
- [x] Tests use established patterns (host! 'localhost')
- [x] Full test suite passes (167 examples, 0 failures)
- [x] No configuration hacks needed

---

## Key Insight

**The most valuable lesson from this module:**

> Blind spot reviews are only useful if you APPLY the lessons BEFORE coding. Reviewing blind spots academically doesn't prevent repeating mistakes - you must actively check for established patterns in the codebase before writing new code.

**Practical application:**
- Before writing `X_spec.rb` → grep for existing `*_spec.rb` and read one
- Before writing `XService` → grep for existing services and read patterns
- Before writing `XController` → grep for existing controllers and read patterns

**Time saved**: Following this approach in future modules will save 20-30 minutes per module (avoiding failed test runs, debugging, and container restarts).

---

## References

- docs/ai-guidance/06-api-endpoint.md (original guidance)
- docs/learning-log/blind-spots/BLIND-SPOTS-MODULE3.md (HostAuthorization lesson)
- docs/learning-log/blind-spots/BLIND-SPOTS-MODULE4.md (error handling patterns)
- docs/learning-log/blind-spots/BLIND-SPOTS-MODULE5.md (string keys handling)
- spec/requests/health_spec.rb (established pattern source)

---

**Status**: ✅ Plan adjusted, implementation complete, ready for commit
**Next**: Apply stash and commit with reference to this document
