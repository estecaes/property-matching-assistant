# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Smart Property Matching Assistant** - A Rails 7 API demo project implementing anti-injection lead qualification with property matching for EasyBroker.

**Status**: Foundation phase (Module 1)
**Architecture**: Rails 7 API + PostgreSQL + Docker + RSpec
**Core Value**: LLM + heuristic cross-validation for prompt injection defense

## Development Commands

### Docker Environment
```bash
# Build containers
docker-compose build

# Create databases
docker-compose run --rm app rails db:create

# Run migrations
docker-compose run --rm app rails db:migrate

# Seed database
docker-compose run --rm app rails db:seed

# Start server
docker-compose up

# Rails console
docker-compose run --rm app rails c
```

### Testing
```bash
# Run all tests
docker-compose run --rm app rspec

# Run specific test file
docker-compose run --rm app rspec spec/services/lead_qualifier_spec.rb

# Run specific test by line number
docker-compose run --rm app rspec spec/services/lead_qualifier_spec.rb:42

# Run tests with documentation format
docker-compose run --rm app rspec --format documentation
```

### Health Check
```bash
curl http://localhost:3000/health
```

## Architecture Overview

### Module-Based Structure
The project is organized into 8 modules (0-7), each building on the previous:
- **Module 0**: AI governance infrastructure (complete)
- **Module 1**: Rails API + Docker + RSpec foundation
- **Module 2**: Domain models (ConversationSession, Message, Property)
- **Module 3**: LLM adapter with CurrentAttributes pattern
- **Module 4**: **CRITICAL** Anti-injection core (LeadQualifier service)
- **Module 5**: Property matching with scoring algorithm
- **Module 6**: POST /run API endpoint
- **Module 7**: Minimal Turbo dashboard

### Core Anti-Injection Pattern

The system implements **dual extraction with cross-validation**:

```ruby
# Two independent extraction paths
llm_profile = extract_from_llm(messages)        # Context-aware, flexible
heuristic_profile = extract_heuristic(messages) # Defensive, regex-based

# Cross-validation detects manipulation
discrepancies = compare_profiles(llm_profile, heuristic_profile)
needs_human_review = discrepancies.any? { |d| d[:diff_pct] > 20 }
```

**Why**: LLMs can be manipulated via prompt injection. Heuristics provide independent verification and generate observable evidence in `discrepancies[]` array.

### Database Schema Design

**ConversationSession** (central model):
```ruby
# JSONB fields (NOT regular JSON)
lead_profile      # jsonb - extracted user preferences
discrepancies     # jsonb - MUST be array [], NOT object {}

# Meta fields
needs_human_review      # boolean
qualification_duration_ms # integer
status                   # string
```

**Critical**: `discrepancies` MUST initialize as `[]` (array) because Module 4 pushes objects: `discrepancies << {...}`. Initializing as `{}` will cause runtime errors.

### Thread-Safe Context Management

**NEVER use `Thread.current`** - use `ActiveSupport::CurrentAttributes` instead:

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :scenario
end

# Set scenario from header
Current.scenario = request.headers['X-Scenario']

# Access in services
LLM::FakeClient.new.extract_profile(messages)  # uses Current.scenario
```

**Why**: Thread safety for concurrent requests, proper request isolation, Rails-idiomatic pattern.

## Critical Edge Cases

### 1. Phone vs Budget Extraction
**Input**: `"presupuesto 3 millones, mi tel 5512345678"`

**Problem**: Both are 10-digit numbers. Naive regex might extract phone as budget.

**Solution**: Heuristic MUST use keyword proximity:
```ruby
/(?:presupuesto|budget)[\s:]*(\d+)\s*millones/i

# Validate: 500K-50M range, NOT 10-digit phone format
return number if number.between?(500_000, 50_000_000)
```

### 2. Budget Discrepancy Detection
**Input**: `"Mi presupuesto es 5 millones pero realmente solo tengo 3"`

**Expected**:
- LLM extracts: 5,000,000 (first mention)
- Heuristic extracts: 3,000,000 (last mention with context)
- Discrepancy: 66.7% difference
- Result: `needs_human_review = true`

### 3. City Requirement for Matching
**Rule**: PropertyMatcher returns `[]` if city is nil/missing.

**Why**: Prevents irrelevant property matches from flooding results.

## Code Quality Standards

### Architecture Constraints
```ruby
# REQUIRED patterns
ActiveSupport::CurrentAttributes   # For thread-safe context (NOT Thread.current)
Service objects                    # For complex business logic
Structured logging                 # JSON to stdout
Explicit validation               # Via ActiveModel or custom

# FORBIDDEN patterns
Thread.current                     # Use CurrentAttributes instead
God objects                        # Single responsibility
Implicit dependencies              # Inject explicitly
Session middleware in API mode     # Rails API mode only
```

### Testing Requirements
```ruby
# Coverage targets
LeadQualifier (Module 4):     100% (critical service)
PropertyMatcher (Module 5):   100% (critical service)
Models with business logic:   >90%
Controllers/endpoints:        >80%
Overall project:             >80%

# Edge cases that MUST have tests
- phone_vs_budget: Budget extraction ignores phone numbers
- budget_mismatch: Discrepancy detection >20%
- missing_city: PropertyMatcher returns empty array
- llm_timeout: Graceful fallback to heuristic only
```

### Controller Pattern
```ruby
# Thin controllers - delegate to services
class RunsController < ApplicationController
  def create
    session = ConversationSession.create!(status: 'active')

    # Service handles business logic
    result = LeadQualifier.call(session)

    render json: result
  end
end
```

### Service Pattern
```ruby
# Single responsibility, explicit returns
class LeadQualifier
  def self.call(session)
    new(session).call
  end

  def call
    # Clear return value, no implicit nil
    @session.tap(&:save!)
  end
end
```

## Development Protocols

### Before Starting a Module
1. Read `docs/ai-guidance/[XX]-module-name.md` completely
2. Check dependencies (ensure previous modules complete)
3. Review constraints and edge cases
4. Identify tests to write first

### During Implementation
1. Follow existing patterns from codebase
2. Write tests first for critical logic (TDD)
3. Use descriptive commit messages referencing module
4. Structured logging for observable behavior

### Commit Message Format
```bash
[ModuleX] Brief description of change

Optional detailed explanation if needed.
Addresses edge case or constraint from guidance.

References: docs/ai-guidance/XX-module.md
```

### Module Completion Checklist
- [ ] All tests pass: `docker-compose run --rm app rspec`
- [ ] No pending tests or skipped specs
- [ ] Code follows existing patterns
- [ ] Logs are structured JSON
- [ ] Commit messages reference module
- [ ] Update learning log if challenges encountered

## Scenario-Based Testing

The system uses `X-Scenario` header for deterministic testing:

```bash
curl -X POST http://localhost:3000/run \
  -H "X-Scenario: budget_seeker" \
  -H "Content-Type: application/json"
```

**Available scenarios** (defined in `LLM::FakeClient`):
- `budget_seeker`: Standard lead, no discrepancies
- `budget_mismatch`: LLM vs heuristic budget conflict (5M vs 3M)
- `phone_vs_budget`: Tests phone number vs budget distinction
- `missing_city`: No city provided, tests PropertyMatcher empty return

**Fallback**: Unknown scenarios fall back to real Anthropic API (requires `ANTHROPIC_API_KEY`).

## Documentation Structure

### AI Guidance
`docs/ai-guidance/[01-07]-module-name.md` - Module-specific implementation guidance with constraints, edge cases, testing requirements.

### Architecture Decisions
- `docs/architecture/adr-001-demo-vs-production.md` - Scope boundaries, trade-offs
- `docs/architecture/adr-002-anti-injection-strategy.md` - Dual extraction rationale
- `docs/architecture/adr-003-current-attributes-pattern.md` - Thread safety approach

### Learning Log
`docs/learning-log/challenges.md` - Real challenges encountered during implementation, solutions, and key learnings for future reference.

### Governance
`.agent/governance.md` - Development rules, protocols, quality gates, escalation procedures.

## Demo vs Production Trade-offs

### Maintained Production Quality
- Anti-injection validation (core value)
- Structured JSON logging
- Testing practices (>80% coverage)
- Clean architecture (POODR, single responsibility)
- Database constraints and validations

### Simplified for Demo Scope
- No authentication/authorization
- Single database (no read replicas)
- In-memory scenario management (no message queue)
- Basic Docker (no multi-stage builds)
- No monitoring/APM (Prometheus, Datadog)
- ActiveRecord search (not Elasticsearch)

**Rationale**: Focus 6-8 hour development time on core value proposition (anti-injection + matching) while maintaining production-quality patterns where they matter for senior evaluation.

## Module Development Workflow

This project uses a structured workflow for implementing each module:

### Before Starting a Module

1. **Review CHECKLIST.md** - Check prerequisites and current module status
2. **Read module guidance** - `docs/ai-guidance/[XX]-module-name.md` completely
3. **Check dependencies** - Ensure previous modules are complete
4. **Plan tasks** - Use TodoWrite tool to track implementation steps

### During Implementation

1. **Follow TDD approach** - Write tests alongside code
2. **Track progress** - Update TodoWrite as you complete tasks
3. **Document challenges** - Note any issues encountered

### After Module Completion

1. **Update CHECKLIST.md** - Mark completed items, update status
2. **Create post-implementation review** - Add entry to `docs/learning-log/module-reviews.md`:
   - What was implemented
   - Blind spots discovered
   - Deviations from guidance
   - Lessons learned
3. **Verify Success Criteria** - Run all validation checks from module guidance
4. **Commit with module reference** - Use `[ModuleX]` prefix

### Critical Files for AI Development

- **CHECKLIST.md** - Active tracking of all pendientes across modules (check FIRST)
- **docs/learning-log/module-reviews.md** - Post-implementation analysis and blind spots
- **docs/ai-guidance/[XX]-module.md** - Module-specific implementation guidance
- **.agent/governance.md** - Development protocols and quality standards
- **.agent/context-routes.yaml** - Semantic routing for problem-solving

## Important Context Routing

For module-specific questions, see `.agent/context-route.yaml` which provides semantic routing by:
- **Intent**: debugging, implementation, testing, refactor, architecture
- **Technical problem**: extraction issues, matching failures, scenario management
- **Project phase**: planning, implementation, testing, debugging

## Success Criteria (Final Demo)

**Technical**:
- `curl -H "X-Scenario: budget_seeker" POST /run` works end-to-end
- All tests pass with meaningful coverage (>80%)
- Logs show structured JSON
- Anti-injection visibly demonstrated via discrepancies[]

**Methodological**:
- All AI guidance documented in `docs/ai-guidance/`
- Learning log captures real challenges
- Commits show natural iterative development
- Architecture decisions explained in ADRs
