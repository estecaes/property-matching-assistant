# AI Guidance Documentation

This directory contains module-specific guidance for AI-assisted development of the Smart Property Matching Assistant.

## Purpose

Each guidance document provides:
- Technical specifications and constraints
- Implementation patterns specific to the module
- Edge cases and testing requirements
- Success criteria and verification steps
- Trade-offs between demo scope and production quality

## Module Overview

| Module | File | Focus Area | Estimated Time |
|--------|------|------------|----------------|
| 0 | (N/A - Infrastructure) | AI governance setup | 30 min |
| 1 | [01-foundation.md](./01-foundation.md) | Rails API + Docker + RSpec | 45 min |
| 2 | [02-domain-models.md](./02-domain-models.md) | Models, migrations, seeds | 1 hour |
| 3 | [03-llm-adapter.md](./03-llm-adapter.md) | CurrentAttributes, FakeClient | 1 hour |
| 4 | [04-anti-injection.md](./04-anti-injection.md) | ⭐ LeadQualifier service | 2.5 hours |
| 5 | [05-property-matching.md](./05-property-matching.md) | PropertyMatcher scoring | 1 hour |
| 6 | [06-api-endpoint.md](./06-api-endpoint.md) | POST /run endpoint | 1.5 hours |
| 7 | [07-minimal-interface.md](./07-minimal-interface.md) | Turbo dashboard | 1 hour |

## How to Use This Documentation

### Before Starting a Module

1. **Read the guidance document** for that module completely
2. **Check dependencies**: Ensure previous modules are complete
3. **Understand constraints**: Note non-negotiable requirements
4. **Review edge cases**: Familiarize yourself with testing requirements

### During Implementation

1. **Follow specifications exactly**: Especially for critical modules (4, 5, 6)
2. **Test as you go**: Don't defer testing to the end
3. **Document challenges**: Update learning log if issues arise
4. **Commit logically**: Reference module number in commit messages

### After Completion

1. **Verify success criteria**: Check all boxes before proceeding
2. **Run full test suite**: Ensure nothing broke
3. **Update TODO list**: Mark module as complete
4. **Review next module**: Prepare for upcoming work

## Critical Modules

### ⭐ Module 4: Anti-Injection Core
This is the **most critical and complex** module. It demonstrates:
- Senior-level defensive programming
- LLM + heuristic cross-validation
- Observable evidence generation
- Edge case handling (phone vs budget)

Budget **2.5 hours** for this module and do NOT rush it.

### Module 6: API Endpoint
Integrates all previous work. Requires careful:
- Error handling
- Response structure
- Scenario management
- End-to-end flow validation

## Principles for All Modules

### Code Quality
- **Clean Code**: Single responsibility, descriptive names
- **POODR**: Prefer composition, avoid god objects
- **Testing**: Write tests first for critical logic
- **Simplicity**: Minimum complexity for requirements

### Demo vs Production
Each guidance document identifies:
- ✅ **Production-quality patterns** maintained in demo
- ⚠️ **Simplified for demo** but documented as trade-offs

### Observable Evidence
All modules should produce:
- Structured JSON logs
- Clear test output
- Descriptive commit messages
- Documentation of decisions

## Documentation Standards

### Each Module Guidance Contains

1. **Objectives**: Clear goals for the module
2. **Technical Specifications**: Code examples and patterns
3. **Implementation Steps**: Ordered tasks
4. **Testing Requirements**: Specific tests to write
5. **Constraints & Edge Cases**: Critical requirements
6. **Success Criteria**: Verification checklist
7. **Next Steps**: Preparation for following module

### Governance Compliance

All guidance follows rules in:
- `.agent/governance.md` - Development protocols
- `.agent/context-routes.yaml` - Documentation routing
- `docs/idea/Blueprint.md` - Overall project plan

## Getting Help

### If Guidance is Unclear
1. Check `.agent/context.md` for general principles
2. Review `docs/architecture/` for architectural context
3. Consult `docs/idea/Blueprint.md` for scope clarity
4. Document ambiguity in learning log for future reference

### If Implementation Fails
1. **Don't skip steps**: Follow implementation order
2. **Check dependencies**: Ensure previous modules are solid
3. **Review constraints**: Verify all requirements are met
4. **Document in learning log**: Capture the challenge

### If Tests Fail
1. **Understand the failure**: Don't just fix symptoms
2. **Check edge cases**: Review guidance for specific scenarios
3. **Verify setup**: Ensure test environment is correct
4. **Never skip tests**: Fix the root cause

## Revision History

| Date | Change | Reason |
|------|--------|--------|
| 2025-12-20 | Initial guidance structure | Module 0 completion |

---

**Status**: Active
**Total Modules**: 8 (including Module 0)
**Current Phase**: Foundation
**Next Review**: After Module 1 completion
