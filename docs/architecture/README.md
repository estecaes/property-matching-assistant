# Architecture Documentation

This directory contains Architecture Decision Records (ADRs) and design documentation for the Smart Property Matching Assistant demo project.

## Purpose

Document architectural decisions, trade-offs, and patterns used in this demo with explicit reasoning about Demo vs Production considerations.

## Architecture Decision Records

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [001](./adr-001-demo-vs-production.md) | Demo vs Production Trade-offs | Active | 2025-12-20 |
| [002](./adr-002-anti-injection-strategy.md) | Anti-Injection Validation Strategy | Active | 2025-12-20 |
| [003](./adr-003-current-attributes-pattern.md) | CurrentAttributes for Scenario Context | Active | 2025-12-20 |

## Reading Guide

### For Understanding Overall Architecture
Start with ADR-001 (Demo vs Production Trade-offs) to understand scope boundaries and which patterns are production-ready vs simplified for demo.

### For Implementation Guidance
Each ADR includes:
- **Context**: Why this decision was needed
- **Decision**: What pattern/approach was chosen
- **Consequences**: Trade-offs and implications
- **Demo vs Production**: What would change at scale

### For Interviews
These ADRs demonstrate:
- Awareness of production concerns even in demo scope
- Thoughtful trade-off analysis
- Understanding of scalability challenges
- Clean Code and POODR alignment

---

**Status**: Active
**Review Cycle**: After major modules (4, 6, 7)
**Maintainer**: Project lead
