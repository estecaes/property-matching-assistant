# Smart Property Matching Assistant - AI Development Context

## Project Overview

This is a **Senior Ruby on Rails demo project** for EasyBroker, implementing an anti-injection lead qualification engine with property matching capabilities.

**Status**: Foundation phase (Módulo 1)
**Timeline**: 7 modules, 6-8 hours total development
**Methodology**: Human-directed development with AI-supervised execution

---

## Core Mission

Build a **production-ready demo** that showcases:
1. Anti-injection validation (LLM + heuristic cross-check)
2. Property matching with business logic
3. Observable evidence (discrepancies[], structured logs)
4. Clean Rails architecture aligned with EasyBroker culture

---

## Architecture Principles

### Non-Negotiable Constraints
- Rails 7 API mode (NO session middleware)
- PostgreSQL with jsonb for structured data
- CurrentAttributes for thread-safe context (NEVER Thread.current)
- Structured JSON logging to stdout
- RSpec tests for critical edge cases
- Anti-injection with discrepancies[] from day 1

### Code Quality Standards
- **Clean Code + POODR**: Single responsibility, small modules
- **Testing first**: RSpec comprehensivo, >80% coverage
- **No over-engineering**: Minimum complexity for current task
- **Explicit constraints**: Document trade-offs Demo vs Production

---

## Development Workflow

### Module-Based Execution
```
Módulo 0: AI Infrastructure ✅
Módulo 1: Foundation (current) 🔄
Módulo 2: Domain Models
Módulo 3: LLM Adapter
Módulo 4: Anti-Injection Core ⭐
Módulo 5: Property Matching
Módulo 6: API Endpoint
Módulo 7: Minimal Interface
```

### Quality Gates per Module
1. Read relevant AI guidance in docs/ai-guidance/
2. Implement with TDD approach
3. Update learning log if challenges found
4. Commit with descriptive message
5. Verify tests pass before next module

---

## Context Routing

For module-specific guidance, refer to:
```yaml
# See .agent/context-routes.yaml for detailed routing
foundation: docs/ai-guidance/01-foundation.md
models: docs/ai-guidance/02-domain-models.md
llm: docs/ai-guidance/03-llm-adapter.md
anti_injection: docs/ai-guidance/04-anti-injection.md
matching: docs/ai-guidance/05-property-matching.md
api: docs/ai-guidance/06-api-endpoint.md
interface: docs/ai-guidance/07-minimal-interface.md
```

---

## Critical Edge Cases to Remember

### 1. Phone vs Budget Extraction
```ruby
# Input: "presupuesto 3 millones, mi tel 5512345678"
# Expected: budget = 3_000_000 (NOT 5_512_345_678)
# Reason: Both are 10-digit numbers, heuristic must distinguish
```

### 2. Budget Discrepancy Detection
```ruby
# LLM: 5M, Heuristic: 3M
# discrepancies = [{field: 'budget', llm: 5000000, heuristic: 3000000, diff_pct: 66.7}]
# needs_human_review = true
```

### 3. Mandatory City for Matching
```ruby
# NO property matching if city is nil or missing
# Fail gracefully, return empty matches[] with reason
```

---

## Forbidden Patterns

❌ **NEVER use**:
- Thread.current for context (use CurrentAttributes)
- Session middleware in API mode
- `discrepancies || []` fallback (initialize as array)
- Overly complex abstractions for one-time use
- Time estimates in plans or documentation

✅ **ALWAYS prefer**:
- Reading existing code before modifications
- Simple solutions over clever ones
- Editing existing files vs creating new ones
- Parallel tool calls when operations are independent
- Testing edge cases explicitly

---

## Communication Style

- Concise responses (CLI-optimized)
- No emojis unless requested
- Technical accuracy over validation
- Objective guidance, respectful corrections
- Direct tool usage without announcement colons

---

## Current Module Context

**Active Module**: Módulo 1 - Foundation
**Primary Goals**:
1. Rails 7 API + PostgreSQL setup
2. Docker configuration
3. RSpec framework
4. Health check endpoint
5. Structured logging

**Reference**: See docs/ai-guidance/01-foundation.md for detailed guidance

---

## Learning Log Protocol

When encountering challenges, architectural decisions, or iterations:
1. Document in docs/learning-log/challenges.md
2. Include problem, attempted solutions, final decision
3. Capture reasoning for future reference
4. Update if pattern emerges across modules

---

## Success Criteria Reminder

**Technical**:
- `curl -H "X-Scenario: budget_seeker" POST /run` works
- Tests pass with meaningful coverage
- Logs show structured JSON
- Anti-injection visibly demonstrated

**Methodological**:
- All AI guidance documented
- Learning log captures real challenges
- Commits show natural iteration
- Architecture decisions explained

---

**Last Updated**: 2025-12-20
**Current Phase**: Foundation
**Next Checkpoint**: Domain Models setup
