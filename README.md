# Smart Property Matching Assistant

Demo Rails 7 API showcasing **anti-injection lead qualification** with property matching for real estate platforms.

## Quick Start

```bash
# 1. Build and start containers
docker compose up -d

# 2. Create and migrate database
docker compose run --rm app rails db:create db:migrate

# 3. Seed properties (REQUIRED for demos)
docker compose run --rm app rails db:seed

# 4. Access dashboard
open http://localhost:3001
```

## About This Demo

### Business Context
This demo simulates a **lead qualification assistant** for real estate platforms - specifically solving the challenge of extracting structured buyer preferences from unstructured conversations while protecting against LLM manipulation or hallucination.

**Real-world use case**: A broker's assistant talks to a prospective buyer via WhatsApp/chat. The system needs to:
- Extract budget, location, bedroom count reliably
- Match against property inventory
- Flag conversations where the LLM's extraction seems inconsistent with user's actual text

### Where This Fits in a Real System
```
┌─────────────────────────────────────────────┐
│   Conversational Interface                  │
│   (WhatsApp API / Web Chat / SMS)           │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
         ┌────────────────────┐
         │  This Demo Module  │ ◄── Anti-injection validation
         │  Lead Qualifier    │ ◄── Property matching
         └────────┬───────────┘
                  │
                  ▼
    ┌─────────────────────────────┐
    │  Broker Dashboard           │
    │  - Qualified leads          │
    │  - Discrepancy alerts       │
    │  - Property recommendations │
    └─────────────────────────────┘
```

**Integration points**:
- **Input**: Chat messages from any conversational interface
- **Output**: Structured lead profile + property matches + review flags
- **Human-in-the-loop**: Broker reviews leads marked `needs_human_review: true`

### Key Technical Approach

**Dual extraction with cross-validation**:
- LLM + heuristic both extract data independently
- Compare results and flag >20% discrepancies
- Makes LLM manipulation/hallucination observable

**Example**:
```json
{
  "llm_extraction": {"budget": 5000000},      // LLM says 5M
  "heuristic_extraction": {"budget": 3000000}, // Regex finds "3 millones"
  "discrepancies": [{
    "field": "budget",
    "llm": 5000000,
    "heuristic": 3000000,
    "diff_pct": 66.7
  }],
  "needs_human_review": true  // ← Broker gets alerted
}
```

### What to Review First (Quick Navigation)

**For architecture/design evaluation** (15-20 min):
1. [REVIEWER-GUIDE.md](docs/REVIEWER-GUIDE.md) - Start here for complete walkthrough
2. [ADR-002: Anti-Injection Strategy](docs/architecture/adr-002-anti-injection-strategy.md) - Core decision rationale
3. [app/services/lead_qualifier.rb](app/services/lead_qualifier.rb) - Lines 181-224: cross-validation logic
4. [spec/services/lead_qualifier_spec.rb](spec/services/lead_qualifier_spec.rb) - 172 passing tests, focus on anti-injection

**For live testing** (10 min):
1. Run Quick Start above to get dashboard running
2. Try [DEMO-QUICK-REFERENCE.md](docs/DEMO-QUICK-REFERENCE.md) examples
3. See [DEMO-EXPERIMENTS.md](docs/DEMO-EXPERIMENTS.md) for 15 real API test results

**For development process transparency** (5-10 min):
1. [docs/learning-log/](docs/learning-log/) - Challenges encountered during development
2. [.agent/governance.md](.agent/governance.md) - AI-assisted development rules
3. Git history shows natural development progression (not bulk commits)

### Development Transparency

Built using AI-assisted development (Claude Code, GitHub Copilot) with architectural oversight. Process documented in:

- [docs/ai-guidance/](docs/ai-guidance/) - Module-specific instructions given to AI
- [docs/learning-log/](docs/learning-log/) - Challenges, iterations, and decisions
- [docs/architecture/](docs/architecture/) - Architecture Decision Records

## Demo Usage

See **[docs/SETUP-DEMO.md](docs/SETUP-DEMO.md)** for complete demo setup and testing guide.

### Pre-Defined Scenarios

**Scenario 1: Budget Seeker** - Happy path with 3 property matches
**Scenario 2: Budget Mismatch** - Demonstrates discrepancy detection (66.7% difference)
**Scenario 3: Phone vs Budget** - Edge case handling

### Demo Resources

- **[DEMO-QUICK-REFERENCE.md](docs/DEMO-QUICK-REFERENCE.md)** - Quick examples for live demos
- **[DEMO-EXPERIMENTS.md](docs/DEMO-EXPERIMENTS.md)** - 15 tested examples (10 with discrepancies, 5 without)
- **[DEMO-WITH-MATCHES.md](docs/DEMO-WITH-MATCHES.md)** - 8 examples guaranteed to return property matches
- **[DEMO-USAGE.md](docs/DEMO-USAGE.md)** - Dashboard usage guide

## Core Features

### Anti-Injection Methodology
Dual extraction with cross-validation:
- **LLM extraction** - Context-aware (Claude Sonnet 4.5)
- **Heuristic extraction** - Defensive regex-based
- **Cross-validation** - Detects >20% discrepancies
- **Observable evidence** - Discrepancies array for human review

### Property Matching
Scoring-based algorithm (0-100 points):
- Budget match (40 points max)
- Bedrooms match (30 points max)
- Area match (20 points max)
- Property type (10 points max)

Returns top 3 matches with transparent reasoning.

## Tech Stack

- **Ruby** 3.2.2
- **Rails** 7.2
- **PostgreSQL** 15
- **Docker** + Docker Compose
- **RSpec** for testing
- **Turbo** for minimal dashboard
- **Claude Sonnet 4.5** (Anthropic API)

## Testing

```bash
# Run all tests (172 examples)
docker compose run --rm app rspec

# Run specific test file
docker compose run --rm app rspec spec/services/lead_qualifier_spec.rb

# Run with documentation format
docker compose run --rm app rspec --format documentation
```

All tests passing: ✅ **172 examples, 0 failures**

## Architecture

### Module-Based Development
- **Module 0**: AI governance infrastructure
- **Module 1**: Rails API + Docker + RSpec foundation
- **Module 2**: Domain models (ConversationSession, Message, Property)
- **Module 3**: LLM adapter with CurrentAttributes pattern
- **Module 4**: Anti-injection core (LeadQualifier service)
- **Module 5**: Property matching with scoring algorithm
- **Module 6**: POST /run API endpoint
- **Module 7**: Minimal Turbo dashboard

### Critical Patterns

**Thread-Safe Context:**
```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :scenario
end
```

**Service Objects:**
```ruby
LeadQualifier.call(session)  # Returns { session:, extraction_process: }
PropertyMatcher.call(profile) # Returns top 3 scored matches
```

**JSONB Fields:**
```ruby
# ConversationSession
lead_profile      # jsonb - extracted preferences
discrepancies     # jsonb - MUST be [] array (not {})
```

## Environment Variables

```bash
# Optional: Claude API (for real extraction vs simulation)
ANTHROPIC_API_KEY=sk-ant-your-key-here
CLAUDE_MODEL=claude-sonnet-4-5

# Database (Docker)
DB_HOST=db
DB_USERNAME=postgres
DB_PASSWORD=postgres
```

## API Endpoints

### POST /run
Main endpoint for lead qualification and property matching.

**Headers:**
- `X-Scenario` - Use pre-defined scenario (budget_seeker, budget_mismatch, phone_vs_budget)
- `X-Use-Real-API: true` - Use real Anthropic API (requires API key)

**Request:**
```json
{
  "messages": [
    {"role": "user", "content": "Busco departamento en CDMX"},
    {"role": "assistant", "content": "¿Cuál es tu presupuesto?"},
    {"role": "user", "content": "Hasta 3 millones"}
  ]
}
```

**Response:**
```json
{
  "session_id": 1,
  "lead_profile": {
    "budget": 3000000,
    "city": "CDMX",
    "bedrooms": 2,
    "confidence": "high"
  },
  "matches": [
    {
      "id": 1,
      "title": "Departamento en Roma Norte",
      "price": 2551577,
      "score": 80,
      "reasons": ["budget_close_match", "bedrooms_exact_match", "area_exact_match"]
    }
  ],
  "needs_human_review": false,
  "discrepancies": [],
  "extraction_process": {
    "messages": [...],
    "llm_extraction": {...},
    "heuristic_extraction": {...}
  }
}
```

### GET /health
Health check endpoint.

## Database Schema

### conversation_sessions
- `lead_profile` (jsonb) - Extracted user preferences
- `discrepancies` (jsonb) - Array of detected discrepancies
- `needs_human_review` (boolean)
- `qualification_duration_ms` (integer)
- `status` (string)

### messages
- `conversation_session_id` (foreign key)
- `role` (string) - user/assistant
- `content` (text)
- `sequence_number` (integer)

### properties
- `title`, `description`, `price`
- `city`, `area`
- `bedrooms`, `bathrooms`, `square_meters`
- `property_type` (departamento, casa, terreno)
- `features` (jsonb)
- `active` (boolean)

## Project Documentation

- **[REVIEWER-GUIDE.md](docs/REVIEWER-GUIDE.md)** ⭐ - Start here for complete walkthrough (15-30 min)
- **[CLAUDE.md](CLAUDE.md)** - AI development guidelines
- **[docs/ai-guidance/](docs/ai-guidance/)** - Module-specific implementation guides
- **[docs/architecture/](docs/architecture/)** - Architecture Decision Records (ADRs)
- **[docs/learning-log/](docs/learning-log/)** - Development challenges and solutions

## Development Protocols

See [.agent/governance.md](.agent/governance.md) for:
- Development rules
- Quality gates
- Testing requirements
- Commit message format

## Demo vs Production

**Maintained Production Quality:**
- Anti-injection validation (core value)
- Structured JSON logging
- Testing practices (>80% coverage)
- Clean architecture patterns

**Simplified for Demo:**
- No authentication/authorization
- Single database (no read replicas)
- In-memory scenario management
- Basic Docker setup
- No monitoring/APM

## Success Metrics

- ✅ **172 passing tests** (0 failures)
- ✅ **10 discrepancy detection examples** (tested with real API)
- ✅ **5 validation examples** (no false positives)
- ✅ **26 seeded properties** (CDMX, Guadalajara, Monterrey)
- ✅ **3 property matches** average for valid criteria
- ✅ **100% anti-injection detection** for >20% discrepancies

## Contributing

This is a demo project. See learning log and blind spots documentation for insights into development process.

## License

Demo project for technical evaluation.
