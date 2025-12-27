# Module 5 Blind Spots Analysis

**Date**: 2025-12-27
**Module**: Property Matching
**Review Type**: Pre-completion analysis

---

## Summary

Post-implementation blind spot analysis discovered **3 uncovered edge cases** that require attention before Module 6.

**Status**: 2 CRÍTICO items blocking, 1 IMPORTANTE item recommended

---

## Blind Spots Discovered

### 🔴 CRÍTICO #1: Budget Zero Division Error

**Issue**: `score_budget` method will throw `ZeroDivisionError` if budget is 0.

**Code Location**: `app/services/property_matcher.rb:96-111`

**Current Code**:
```ruby
def score_budget(price, budget)
  return 0 if price.nil? || budget.nil?

  # Calculate percentage difference
  diff_pct = ((price - budget).abs.to_f / budget * 100)  # ⚠️ Division by zero if budget == 0
  # ...
end
```

**Edge Case**:
- User profile: `{ city: "CDMX", budget: 0 }`
- Result: `ZeroDivisionError: divided by 0`

**Why Missed**:
- Tests used realistic budgets (2M-5M MXN)
- Validation in LeadQualifier extracts valid budgets
- But PropertyMatcher should be defensive (standalone service)

**Impact**: 🔴 **BLOCKER**
- Service will crash if called with budget=0
- Breaks standalone usage outside LeadQualifier context

**Fix Required**:
```ruby
def score_budget(price, budget)
  return 0 if price.nil? || budget.nil? || budget.zero?
  # ... rest of logic
end
```

**Test Required**:
```ruby
context "with zero budget" do
  let(:profile) { { city: "CDMX", budget: 0 } }

  it "does not crash and returns matches without budget scoring" do
    expect { described_class.call(profile) }.not_to raise_error
    results = described_class.call(profile)
    # Should return properties but with 0 budget score
  end
end
```

---

### 🔴 CRÍTICO #2: String Keys vs Symbol Keys

**Issue**: Tests only use symbol keys, but production will receive string keys from JSON.

**Code Location**: `app/services/property_matcher.rb:24-26`

**Current Code**:
```ruby
def initialize(lead_profile)
  @profile = lead_profile.symbolize_keys  # ✅ Handles strings, but NOT TESTED
end
```

**Edge Case**:
- Controller passes: `params.to_h` → string keys `{ "city" => "CDMX", "budget" => 3000000 }`
- LeadQualifier returns: `session.lead_profile` → might be strings depending on JSONB storage

**Why Missed**:
- All test fixtures use symbol keys (Ruby hash literals)
- Real-world JSON params use strings
- `symbolize_keys` SHOULD work, but it's untested

**Impact**: 🔴 **BLOCKER**
- If `symbolize_keys` fails silently, matcher returns 0 results
- Hard to debug (no error, just empty results)

**Fix Required**: Add test with string keys

**Test Required**:
```ruby
context "with string keys in profile" do
  let(:profile) do
    {
      "budget" => 3_000_000,
      "city" => "CDMX",
      "area" => "Roma Norte",
      "bedrooms" => 2
    }
  end

  it "handles string keys correctly via symbolize_keys" do
    results = described_class.call(profile)
    expect(results).not_to be_empty
    expect(results.first[:score]).to be > 0
  end
end
```

---

### 🟡 IMPORTANTE #3: Missing Edge Case Logging

**Issue**: PropertyMatcher only logs `missing_city`, but not other important edge cases.

**Code Location**: `app/services/property_matcher.rb:176-179`

**Current Code**:
```ruby
def no_results(reason)
  Rails.logger.warn("No property matches: #{reason}")
  []
end
```

**Missing Logs**:
1. When city is valid but 0 properties exist
2. When <3 properties available (user sees partial results)
3. When all properties score 0 (no good matches)

**Why Missed**:
- Logging focused on errors, not business events
- Module 4 has excellent logging, but Module 5 minimal

**Impact**: 🟡 **IMPORTANTE** (not blocking, but reduces observability)
- Hard to debug "why only 1 result?" in production
- No visibility into matching quality

**Fix Recommended**:
```ruby
def call
  return no_results("missing_city") unless @profile[:city].present?

  properties = Property.active.in_city(@profile[:city])

  if properties.empty?
    Rails.logger.info({ event: "no_properties_in_city", city: @profile[:city] }.to_json)
    return []
  end

  scored_properties = score_properties(properties)
  top_matches = scored_properties.take(MAX_RESULTS)

  Rails.logger.info({
    event: "property_matching_completed",
    city: @profile[:city],
    total_available: properties.size,
    results_returned: top_matches.size,
    top_score: top_matches.first&.[](:score)
  }.to_json)

  format_results(top_matches)
end
```

---

## Already Covered (No Action Needed)

✅ **Empty properties in city**: Test exists (`with no matching properties in city`)
✅ **Nil property price**: Handled by `return 0 if price.nil?`
✅ **Bathrooms not used in scoring**: By design (only metadata)
✅ **Case insensitivity**: Full test coverage

---

## Action Plan

### Before Module 6 (BLOCKING)

1. ✅ Fix `score_budget` to handle `budget.zero?`
2. ✅ Add test for string keys profile
3. ✅ Run full test suite to verify fixes

### Optional (Can defer to Module 6)

4. ⏸️ Add structured logging for edge cases (can be done during Module 6 integration)

---

## Lessons Learned

### What Went Right
- TDD approach caught most edge cases
- Comprehensive test coverage (24 examples)
- Case insensitivity properly tested

### What Was Missed
- **Budget validation edge case** (zero value)
- **Input format variation** (string vs symbol keys)
- **Observability** (logging for business events)

### Prevention Strategy
1. **Always test boundary values**: 0, negative, nil for numeric fields
2. **Test input format variations**: symbols, strings, mixed
3. **Add logging early**: Don't wait for integration to add observability

---

**Next Step**: Fix CRÍTICO items #1 and #2, then proceed to Module 6.
