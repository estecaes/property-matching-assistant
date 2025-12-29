# Reviewer's Guide: Smart Property Matching Assistant

**Estimated review time**: 30-40 minutes for complete evaluation
**Quick review**: 15 minutes (sections marked with ⚡)

---

## What This Demo Shows

### Business Problem
Real estate platforms qualify leads from unstructured conversations (WhatsApp, web chat). Challenge: When an LLM says "user's budget is 5 million pesos" but the actual text says "3 millones", how to detect the discrepancy?

### Technical Approach
Dual extraction (LLM + heuristic) with cross-validation.

**Not implemented** (production considerations):
- Authentication/authorization
- Rate limiting / abuse prevention
- Real-time WebSocket chat
- Multi-tenancy for brokers
- Monitoring/APM dashboards
- Horizontal scaling infrastructure

**Focus**: Core cross-validation algorithm + property matching logic + testing coverage.

---

## 15-Minute Quick Review Path ⚡

### 1. Run the Demo (5 min)
```bash
# From project root
docker compose up -d
docker compose run --rm app rails db:create db:migrate db:seed
open http://localhost:3001

# Click "Scenario 2: Budget Mismatch" button
# Observe the yellow discrepancy alert in results
```

**What to look for**:
- Results show both LLM and heuristic extractions side-by-side
- Discrepancy detected automatically (66.7% difference)
- System flags `needs_human_review: true`
- Property matches still returned (graceful degradation)

### 2. Review Core Service (5 min)
Open `app/services/lead_qualifier.rb`:

**Lines 181-224**: `compare_profiles` method
- Cross-validates LLM vs heuristic extraction
- Calculates percentage differences for numeric fields
- Builds discrepancies array with observable evidence
- Critical threshold: >20% difference triggers review

**Lines 64-73**: `extract_from_llm`
- Structured JSON output from Claude API
- Fallback to default profile on errors
- Schema validation with error handling

**Lines 75-120**: `extract_heuristic` and `extract_budget`
- Regex-based extraction (defensive)
- Budget pattern with monetary context to avoid phone numbers
- City/area matching against known valid values

### 3. Check Testing Quality (5 min)
```bash
docker compose run --rm app rspec spec/services/lead_qualifier_spec.rb --format documentation
```

**Look for**:
- ✅ 172 examples, 0 failures
- Anti-injection test cases (budget discrepancy, city mismatch)
- Edge case handling (phone vs budget, LLM unavailable)
- Happy path validation (no false positives)

---

## 30-Minute Complete Review Path

### Phase 1: Architecture Understanding (10 min)

#### Start Here: Architecture Decision Record
📄 **`docs/architecture/adr-002-anti-injection-strategy.md`**

**Key questions answered**:
- Why dual extraction instead of just LLM?
- Why 20% threshold for discrepancies?
- What are the trade-offs?

#### Component Overview

**Architecture flow**:
```
ConversationSession (state management)
    ↓
LeadQualifier (anti-injection engine)
    ├── LLM extraction (Claude Sonnet 4.5)
    ├── Heuristic extraction (regex-based)
    └── Cross-validation (compare + flag)
    ↓
PropertyMatcher (scoring algorithm)
    ↓
JSON response (with discrepancies array)
```

**Database schema**: Check `db/schema.rb`
- `discrepancies` field is **jsonb array** (not hash) - critical for aggregation
- `lead_profile` jsonb for flexible schema
- Indexed on `city`, `price` for matching performance

### Phase 2: Code Quality Review (10 min)

#### Service Objects
📁 **`app/services/`**

**Patterns to observe**:
- Single responsibility (each service does one thing)
- Thin controllers (`app/controllers/runs_controller.rb`)
- No business logic in models
- Clear method signatures with explicit parameters

#### Thread Safety
📄 **`app/models/current.rb`**

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :scenario  # Thread-safe context management
end
```

**Note**: `CurrentAttributes` provides thread-safe context management for concurrent requests, avoiding state leakage issues with `Thread.current`.

#### Edge Case Handling
📄 **`app/services/lead_qualifier.rb` (lines 91-120)**

Budget extraction that **distinguishes phone numbers from budgets**:
```ruby
# Matches: "presupuesto 3 millones" ✅
# Ignores: "mi teléfono es 5512345678" ❌ (10+ digits without monetary context)
```

Test coverage: `spec/services/lead_qualifier_spec.rb` lines 81-110 and 144-169

### Phase 3: Testing Coverage (10 min)

#### Test Structure
```bash
# Run all tests with documentation format
docker compose run --rm app rspec --format documentation
```

**Coverage areas** (172 examples total):
- **LeadQualifier**: 89 examples
  - Anti-injection scenarios (15 examples)
  - Edge cases (phone vs budget, missing data, LLM errors)
  - Happy paths (no false positives)
- **PropertyMatcher**: 48 examples
  - Scoring algorithm validation
  - Edge cases (no city, budget out of range)
- **Integration**: 35 examples
  - Full API endpoint behavior
  - Error handling
  - Response structure validation

#### Key Test Files to Review

📄 **`spec/services/lead_qualifier_spec.rb`**
- Lines 11-110: Scenario-based tests (budget_seeker, budget_mismatch, phone_vs_budget)
- Lines 113-180: Real API integration tests with VCR cassettes
- Lines 112-140: Edge cases and error handling (LLM extraction failures)

📄 **`spec/requests/runs_spec.rb`**
- Integration tests for POST /run endpoint
- Scenario-based testing
- Error response validation

---

## Development Process Transparency

### AI-Assisted Development Governance

Built using Claude Code and GitHub Copilot with oversight rules.

#### Governance Framework
📄 **`.agent/governance.md`**

**Rules applied**:
- AI generates code, human validates architecture
- Every module has pre-written guidance document
- Learning log captures challenges and decisions
- Quality gates before moving to next module

#### Module-Specific Guidance
📁 **`docs/ai-guidance/`**

**7 modules, each with explicit instructions**:
1. Module 1: Foundation (Rails setup, Docker, RSpec)
2. Module 2: Domain models (schema design)
3. Module 3: LLM adapter (CurrentAttributes pattern)
4. Module 4: Anti-injection core (the critical logic) ⭐
5. Module 5: Property matching (scoring algorithm)
6. Module 6: API endpoint (error handling)
7. Module 7: Dashboard (Turbo Rails UI)

**Example**: Check `docs/ai-guidance/04-anti-injection.md` to see exact instructions given to AI before code generation.

#### Learning Log
📁 **`docs/learning-log/`**

**Challenges documented**:
- Thread safety pitfall (Thread.current vs CurrentAttributes)
- JSONB schema decisions (array vs hash for discrepancies)
- Budget regex complexity (avoiding phone number false positives)
- Cross-validation threshold tuning (why 20%?)

Documents decisions and iterations during development.

---

## Live Demo Examples

### Using the Dashboard (Visual)

1. **Scenario 1: Budget Seeker** (happy path)
   - Click button → See green success banner
   - 3 property matches returned
   - No discrepancies detected

2. **Scenario 2: Budget Mismatch** (anti-injection)
   - Click button → See yellow alert banner
   - Discrepancies table shows: LLM=5M, Heuristic=3M, Diff=66.7%
   - Property matches still shown (graceful)
   - Flag: "Needs human review: Yes"

3. **Scenario 3: Phone vs Budget** (edge case)
   - Click button → Extracts budget correctly (3M)
   - Does NOT confuse phone number (5512345678) with budget
   - Test: `spec/services/lead_qualifier_spec.rb` lines 81-110

### Using the API (Programmatic)

📄 **`docs/DEMO-QUICK-REFERENCE.md`** - Copy-paste curl examples

**Budget Mismatch Example**:
```bash
curl -X POST http://localhost:3000/run \
  -H "Content-Type: application/json" \
  -H "X-Scenario: budget_mismatch" \
  -d '{
    "messages": [
      {"role": "user", "content": "Busco departamento con presupuesto de 3 millones"},
      {"role": "assistant", "content": "¿En qué ciudad?"},
      {"role": "user", "content": "CDMX, en Roma Norte"}
    ]
  }'
```

**Expected Response**:
```json
{
  "needs_human_review": true,
  "discrepancies": [
    {
      "field": "budget",
      "llm": 5000000,
      "heuristic": 3000000,
      "diff_pct": 66.7
    }
  ],
  "matches": [...],
  "extraction_process": {
    "llm_extraction": {"budget": 5000000, ...},
    "heuristic_extraction": {"budget": 3000000, ...}
  }
}
```

Observable evidence allows brokers to make informed decisions.

---

## Real API Testing (Optional Deep Dive)

### Using Anthropic's Claude API

📄 **`docs/DEMO-EXPERIMENTS.md`** - 15 real API test results

**Setup**:
```bash
# Add to .env
ANTHROPIC_API_KEY=sk-ant-your-key-here

# Send request with real API
curl -X POST http://localhost:3000/run \
  -H "X-Use-Real-API: true" \
  -d '{"messages": [...]}'
```

**Test results documented**:
- 10 examples with discrepancies detected ✅
- 5 examples with no discrepancies (validation) ✅
- Response times: 1.2s - 3.5s avg
- False positive rate: 0% (no incorrect flags)

---

## Production Considerations (What's NOT Implemented)

### Intentional Simplifications

**Authentication/Authorization**
- Not implemented: User sessions, API keys, role-based access
- Production needs: JWT tokens, OAuth, broker tenant isolation

**Scalability**
- Not implemented: Load balancers, read replicas, caching layer
- Production needs: Redis for sessions, Elasticsearch for search, CDN for assets

**Monitoring**
- Not implemented: APM, error tracking, metrics dashboards
- Production needs: New Relic/Datadog, Sentry, custom dashboards

**Real-Time Chat**
- Not implemented: WebSocket connections, typing indicators
- Production needs: Action Cable, Redis pub/sub, presence detection

### Trade-offs Summary

**Maintained from production standards**:
- ✅ Anti-injection validation (core value)
- ✅ Structured logging (JSON to stdout)
- ✅ Test coverage (172 passing tests)
- ✅ Service-based architecture (service objects, thin controllers)

**Simplified for demo scope**:
- ⚠️ In-memory scenario management (production: database-backed)
- ⚠️ Single database instance (production: read replicas)
- ⚠️ No background jobs (production: Sidekiq for async processing)
- ⚠️ Basic Docker setup (production: Kubernetes/ECS)

---

## Questions for Discussion

### Architecture
1. **Cross-validation threshold**: Currently 20% for discrepancies. Would you adjust this? Why?
2. **Graceful degradation**: System returns matches even with discrepancies. Alternative: block until human reviews?
3. **Heuristic complexity**: Regex-based extraction. Alternative: spaCy NER? Second LLM for validation?

### Business Logic
4. **Property matching**: Scoring algorithm priorities. Would you weight differently?
5. **Human-in-the-loop**: When to require broker review? Current: >20% discrepancy or low confidence. Add more triggers?

### Technical Implementation
6. **Testing coverage**: 172 examples for core services. What additional edge cases would you add?
7. **LLM failover**: Currently falls back to heuristic-only. Alternative strategies?

---

## Getting Help

**Stuck on setup?** → Check `docs/SETUP-DEMO.md`
**Want more test examples?** → See `docs/DEMO-EXPERIMENTS.md`
**Questions about architecture decisions?** → Review `docs/architecture/*.md`
**Curious about development process?** → Read `docs/learning-log/*.md`