# ADR-002: Anti-Injection Validation Strategy

**Status**: Active
**Date**: 2025-12-20
**Context**: Core differentiator for demo - preventing LLM manipulation

---

## Context

LLMs can be manipulated through prompt injection, where malicious input causes the model to extract incorrect data. For a lead qualification system, this could mean:
- Extracting phone numbers as budget amounts
- Manipulating property preferences
- Inserting false location data

We need a **defensive validation strategy** that:
1. Detects potential manipulation
2. Provides observable evidence
3. Requires minimal manual review overhead
4. Demonstrates senior-level security thinking

---

## Decision

Implement **cross-validation architecture** with dual extraction paths:

```
User Input
    ├── Path 1: LLM Extraction (Claude API)
    │   └── Flexible, context-aware interpretation
    │
    ├── Path 2: Heuristic Extraction (Regex + Rules)
    │   └── Strict, defensive pattern matching
    │
    └── Cross-Validation
        ├── Compare extracted values
        ├── Calculate discrepancies
        └── Flag for human review if threshold exceeded
```

### Implementation Pattern

```ruby
class LeadQualifier
  def call(session)
    # Dual extraction
    llm_profile = extract_from_llm(session.messages)
    heuristic_profile = extract_heuristic(session.messages)

    # Cross-validation
    discrepancies = compare_profiles(llm_profile, heuristic_profile)

    # Decision logic
    session.lead_profile = determine_final_profile(llm_profile, heuristic_profile)
    session.discrepancies = discrepancies
    session.needs_human_review = discrepancies.any? { |d| d[:diff_pct] > 20 }

    session.save!
  end
end
```

### Discrepancy Structure

```ruby
discrepancies = [
  {
    field: 'budget',
    llm_value: 5_000_000,
    heuristic_value: 3_000_000,
    diff_pct: 66.7,
    confidence: 'low'
  }
]
```

---

## Alternatives Considered

### 1. LLM-Only with Confidence Scores
**Approach**: Use only LLM extraction, rely on Claude's confidence indicators
**Rejected because**:
- Confidence scores don't detect adversarial inputs
- No independent verification
- Black box decision making

### 2. Heuristic-Only (Traditional NLP)
**Approach**: Use only regex and pattern matching
**Rejected because**:
- Misses contextual understanding ("around 3 million" vs "3 million")
- Brittle against natural language variation
- Doesn't demonstrate modern AI integration

### 3. Multiple LLM Consensus
**Approach**: Query multiple LLMs (Claude, GPT-4, etc.) and compare
**Rejected because**:
- Cost prohibitive for demo
- Latency impact
- All LLMs vulnerable to similar injection patterns

### 4. Rule-Based Validation Post-LLM
**Approach**: LLM extraction + validation rules afterward
**Rejected because**:
- Doesn't generate observable evidence
- Binary pass/fail instead of discrepancy details
- Less informative for human review

---

## Consequences

### Positive
✅ **Observable evidence**: discrepancies[] array shows exact mismatches
✅ **Human-in-loop**: System knows when to escalate
✅ **Defense in depth**: Two independent validation paths
✅ **Senior signal**: Demonstrates security thinking and architecture

### Negative
⚠️ **Increased complexity**: Two extraction implementations to maintain
⚠️ **Potential false positives**: Natural language ambiguity may cause flags
⚠️ **Latency**: Sequential extraction paths add processing time

### Mitigations
- **Keep heuristics simple**: Regex for numbers, city names from whitelist
- **Tune threshold**: 20% discrepancy allows for reasonable variation
- **Async processing**: In production, both extractions run in parallel
- **Clear documentation**: Test cases demonstrate edge cases

---

## Critical Edge Cases

### Phone vs Budget
```ruby
# Input: "presupuesto 3 millones, mi tel 5512345678"

# Heuristic must:
1. Identify "presupuesto" keyword
2. Extract associated number (3,000,000)
3. Distinguish from phone number (10 digits with context)

# LLM must:
1. Understand context clues
2. Not confuse phone format with budget format
3. Return both fields correctly
```

### Budget Format Variations
```ruby
# All should extract as 3,000,000 MXN
"3 millones"
"3M"
"$3,000,000"
"tres millones"
"alrededor de 3 millones"
```

### Missing Data Handling
```ruby
# LLM might infer, heuristic won't find anything
User: "Busco algo familiar en la Roma"

# Expected:
llm: { area: "Roma", bedrooms: 3 (inferred from "familiar") }
heuristic: { area: "Roma" }
discrepancy: { field: 'bedrooms', llm: 3, heuristic: nil, confidence: 'low' }
```

---

## Testing Strategy

### Unit Tests
- LLM extraction with mocked API responses
- Heuristic extraction with various input formats
- Discrepancy calculation logic

### Integration Tests
- End-to-end scenarios (budget_seeker, budget_mismatch, phone_vs_budget)
- Threshold boundary testing (19% vs 21% discrepancy)
- Missing field handling

### Scenario-Based Tests
```ruby
RSpec.describe LeadQualifier do
  context 'budget_mismatch scenario' do
    it 'detects LLM vs heuristic discrepancy' do
      # LLM: 5M, Heuristic: 3M
      expect(session.discrepancies).to include(
        hash_including(field: 'budget', diff_pct: 66.7)
      )
      expect(session.needs_human_review).to be true
    end
  end
end
```

---

## Production Enhancements

If scaling to production:

### Enhanced Heuristics
- Machine learning for number extraction context
- Named entity recognition (NER) for locations
- Synonym expansion for property terms

### LLM Improvements
- Few-shot examples in prompts for consistency
- Structured output validation (JSON schema)
- Fallback to simpler model on timeout

### Monitoring
- Track discrepancy rates over time
- Alert on unusual patterns
- A/B test threshold values

### Performance
- Parallel extraction (LLM + heuristic simultaneously)
- Cache common patterns
- Batch processing for multiple sessions

---

## EasyBroker Alignment

### Security Mindset
Matches EasyBroker's emphasis on web security (XSS, CSRF, SQL Injection) by demonstrating defensive programming for AI-specific vulnerabilities.

### Testing Culture
Comprehensive edge case coverage aligns with "escribimos muchas pruebas" culture.

### Product Thinking
Focuses on business value (accurate lead qualification) over technical complexity.

---

## References

- OWASP LLM Top 10: Prompt Injection (#1)
- Anthropic Prompt Engineering Guide: https://docs.anthropic.com/claude/docs/
- Blueprint: Module 4 - Anti-Injection Core
- Learning Log: Edge case challenges during implementation

---

**Review Trigger**: After Module 4 completion
**Owner**: Project lead
**Last Updated**: 2025-12-20
