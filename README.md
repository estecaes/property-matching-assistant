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
