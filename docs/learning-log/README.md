# Learning Log

This directory captures challenges, iterations, and architectural decisions encountered during development.

## Purpose

Document the **real development process** including:
- Challenges that required rethinking initial approach
- Edge cases discovered during implementation
- Architectural iterations and reasoning
- Patterns that emerged across modules

This is NOT a fictional log - only actual challenges are documented.

## Structure

### [challenges.md](./challenges.md)
Problems encountered and solutions found during implementation.

### [iterations.md](./iterations.md)
Architectural changes made after initial implementation.

### [decisions.md](./decisions.md)
Key decisions made during development with context and trade-offs.

### [module-reviews.md](./module-reviews.md)
Post-implementation reviews and summaries for each completed module.

### [blind-spots/](./blind-spots/)
Systematic analysis of potential issues discovered after module completion.
- `BLIND-SPOTS-MODULE{N}.md` - Comprehensive analysis with severity levels
- `module{N}-fixes.md` - Actionable fixes prioritized by urgency
- See [blind-spots/README.md](./blind-spots/README.md) for detailed usage guide

## When to Document

### Always Document
- When initial approach fails and requires pivot
- When edge case requires architectural change
- When test failure reveals design flaw
- When performance issue requires optimization
- When ambiguity requires clarification and decision

### Never Document
- Routine implementation that matches plan
- Expected challenges already in guidance
- Typos or trivial fixes
- Hypothetical future scenarios

## Format

Each entry should include:
- **Module context**: Which module was being worked on
- **Problem description**: What went wrong or was unclear
- **Attempted solutions**: What was tried and why it didn't work
- **Final solution**: What worked and why
- **Key learnings**: Insights for future work
- **References**: Links to commits, docs, or external resources

## Examples of Log-Worthy Challenges

✅ **Document these**:
- "Heuristic budget extraction was matching phone numbers, required context-aware regex"
- "discrepancies[] was initialized as {} instead of [], caused Module 4 to fail"
- "RSpec factory was creating invalid test data due to validation order"
- "Docker PostgreSQL version mismatch caused jsonb support issues"

❌ **Don't document these**:
- "Fixed typo in model name"
- "Ran bundle install to add new gem"
- "Followed guidance exactly and it worked"
- "Read documentation before implementing"

---

**Status**: Active
**Update Frequency**: As challenges occur
**Reviewer**: Project lead before final submission
