# AI Development Governance Framework

## Purpose

This document establishes **rules and protocols** for AI-assisted development to ensure:
1. **Human oversight**: Architecture and critical decisions remain human-directed
2. **Quality standards**: Code meets EasyBroker's Clean Code + POODR culture
3. **Transparency**: All AI usage is auditable and documented
4. **Learning capture**: Challenges and iterations are preserved

---

## Core Principles

### 1. Human-Directed Execution
✅ **Human responsibilities**:
- Architectural decisions and trade-offs
- Module sequencing and scope definition
- Quality standards and acceptance criteria
- Edge case identification
- Final code review and validation

✅ **AI responsibilities**:
- Code generation following specifications
- Test scaffolding
- Documentation formatting
- Repetitive task execution
- Suggesting patterns based on context

❌ **AI must NOT**:
- Make architectural decisions autonomously
- Skip or modify constraints without human approval
- Generate code without reading existing patterns first
- Proceed with ambiguous requirements

---

## Documentation Requirements

### Before Implementation (Per Module)
1. **Read module-specific guidance** from docs/ai-guidance/
2. **Verify understanding** of constraints and edge cases
3. **Check architecture docs** if pattern is unclear
4. **Ask clarifying questions** rather than assume

### During Implementation
1. **Follow existing patterns** from codebase
2. **Write tests first** for critical logic
3. **Use descriptive commit messages** referencing module
4. **Log structured events** for observable behavior

### After Implementation
1. **Update learning log** if challenges encountered
2. **Document trade-offs** made during development
3. **Verify tests pass** before marking module complete
4. **Note any deviations** from original plan

---

## Code Quality Standards

### Testing Requirements
```ruby
# Required test coverage
- Critical services (LeadQualifier, PropertyMatcher): 100%
- Models with business logic: >90%
- Controllers and endpoints: >80%
- Overall project: >80%

# Edge cases that MUST have tests
- Phone vs budget extraction
- Budget discrepancy detection
- Missing city handling
- LLM timeout/failure scenarios
- Invalid scenario header handling
```

### Architecture Constraints
```ruby
# REQUIRED patterns
ActiveSupport::CurrentAttributes   # For thread-safe context
Service objects                    # For complex business logic
Explicit validation                # Via ActiveModel or custom
Structured logging                 # JSON to stdout

# FORBIDDEN patterns
Thread.current                     # Use CurrentAttributes instead
God objects                        # Single responsibility
Implicit dependencies              # Inject explicitly
Magic numbers                      # Use constants/configs
```

### Rails-Specific Guidelines
```ruby
# Controller layer
- Thin controllers, delegate to services
- No business logic in controllers
- Explicit error handling with rescue_from

# Model layer
- No callbacks for business logic
- Use concerns sparingly
- Database constraints match model validations

# Service layer
- Single responsibility per service
- Explicit return values (no implicit nil)
- Clear error handling with custom exceptions
```

---

## Module Development Protocol

### Module Start Checklist
- [ ] **Review CHECKLIST.md** - Verify prerequisites and module status
- [ ] Read docs/ai-guidance/XX-module-name.md completely
- [ ] Understand constraints and edge cases
- [ ] Check dependencies on previous modules
- [ ] Review previous module post-implementation notes in module-reviews.md
- [ ] Identify tests to write first
- [ ] Plan commit structure (1-3 commits per module)

### Module Completion Checklist
- [ ] All tests pass (`rspec spec/`)
- [ ] No pending tests or skipped specs
- [ ] Code follows existing patterns
- [ ] Logs are structured JSON
- [ ] Commit messages are descriptive
- [ ] **CHECKLIST.md updated** - Mark completed items
- [ ] **module-reviews.md updated** - Post-implementation analysis added

### Module Sign-Off
Each module requires explicit verification:
1. Run tests: `docker-compose run --rm app rspec spec/`
2. Check logs: Ensure JSON structure is correct
3. Manual test: Verify behavior matches spec
4. Review diff: Ensure no unintended changes
5. **Complete post-implementation review**: Document in module-reviews.md:
   - What was implemented
   - Blind spots discovered
   - Deviations from guidance
   - Lessons learned
   - Prioritized pendientes (CRÍTICO/IMPORTANTE/OPCIONAL)
6. **Update CHECKLIST.md**: Mark module status and update next actions

---

## Learning Log Guidelines

### When to Document
Document in `docs/learning-log/challenges.md` when:
- Initial approach didn't work as expected
- Edge case discovered during implementation
- Architectural decision required deviation from plan
- Performance issue required optimization
- Pattern emerged that should be reused

### What to Capture
```markdown
## Challenge: [Brief title]
**Module**: X - Module Name
**Date**: YYYY-MM-DD

**Problem**:
[What went wrong or what was unclear]

**Attempted Solutions**:
1. [First approach and why it failed]
2. [Second approach and why it failed]

**Final Solution**:
[What worked and why]

**Key Learnings**:
- [Insight for future modules]
- [Pattern to reuse]
- [Trade-off made]

**References**:
- [Links to docs, commits, or external resources]
```

---

## Commit Message Standards

### Format
```
[ModuleX] Brief description of change

Optional detailed explanation if needed.
Addresses edge case or constraint from guidance.

References: docs/ai-guidance/XX-module.md
```

### Examples
```bash
# Good
git commit -m "[Module1] Add PostgreSQL configuration with jsonb support

Configured database.yml for development/test environments.
Added explicit jsonb column type in schema for future use.

References: docs/ai-guidance/01-foundation.md"

# Bad
git commit -m "Add database"  # Too vague
git commit -m "Fixed bug"     # No context
```

---

## AI Interaction Protocols

### When to Use Task Tool
Use Task with specialized agents when:
- Searching codebase for patterns (use Explore agent)
- Complex multi-step implementation (use general-purpose)
- Multiple file coordination needed

### When to Use Direct Tools
Use Read/Edit/Write directly when:
- Single file modification
- Clear path to target file
- Pattern already known

### Parallel vs Sequential
**Parallel** (single message, multiple tools):
```ruby
# When operations are independent
- Reading multiple files
- Running independent tests
- Checking multiple patterns
```

**Sequential** (wait for results):
```ruby
# When operations depend on previous results
- Read file → Edit based on content
- Create migration → Run migration
- Generate code → Run tests
```

---

## Quality Gates

### Before Pushing Code
1. **All tests green**: No pending, no failures
2. **No warnings**: RSpec should be clean
3. **Logs verify**: Check structured JSON output
4. **Edge cases covered**: Per module guidance
5. **Documentation current**: Learning log if needed

### Before Module Completion
1. **Module checklist complete**: All items checked
2. **Guidance followed**: No constraint violations
3. **Commits logical**: Each commit is reversible
4. **Next module ready**: Dependencies clear

### Before Demo Submission
1. **All modules complete**: 0-7 finished
2. **End-to-end tests pass**: All scenarios work
3. **Documentation complete**: AI guidance + learning log
4. **README accurate**: Setup instructions verified
5. **Commits natural**: Show iterative development

---

## Escalation Protocols

### When AI is Uncertain
If AI cannot determine the correct approach:
1. **State ambiguity clearly**: Don't guess
2. **Present options**: With trade-offs
3. **Request human decision**: Wait for guidance
4. **Document decision**: In learning log

### When Constraints Conflict
If guidance conflicts with reality:
1. **Surface conflict explicitly**: Don't silently ignore
2. **Propose resolution**: With reasoning
3. **Wait for approval**: Don't proceed autonomously
4. **Update guidance**: If constraint was incorrect

### When Tests Fail
If implementation breaks existing tests:
1. **Analyze failure**: Understand root cause
2. **Check if expected**: Based on refactoring
3. **Fix or update**: Depending on cause
4. **Never skip tests**: Fix the problem

---

## Revision History

| Date       | Change                              | Reason                          |
|------------|-------------------------------------|---------------------------------|
| 2025-12-20 | Initial governance framework        | Módulo 0 setup                  |
| 2025-12-21 | Add CHECKLIST.md and module-reviews.md protocol | Systematic tracking and post-implementation analysis |

---

## References

- **Active Tracking**: CHECKLIST.md (root) - Check FIRST before starting work
- **Post-Implementation**: docs/learning-log/module-reviews.md - Blind spots and lessons learned
- **Blueprint**: docs/idea/Blueprint.md
- **AI Guidance**: docs/ai-guidance/*.md
- **Learning Log**: docs/learning-log/challenges.md
- **Architecture Decisions**: docs/architecture/*.md

---

**Status**: Active
**Review Cycle**: After each module completion
**Owner**: Project lead (human)
