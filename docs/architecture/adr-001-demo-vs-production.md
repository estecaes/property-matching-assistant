# ADR-001: Demo vs Production Trade-offs

**Status**: Active
**Date**: 2025-12-20
**Context**: EasyBroker Senior Rails Engineer demo project

---

## Context

This is a **demo project** designed to showcase senior-level Rails engineering skills and domain understanding for EasyBroker. It must balance:
- **Technical depth**: Demonstrating production-quality patterns
- **Scope realism**: Completable in 6-8 hours of development
- **Business relevance**: Directly applicable to real estate lead qualification

The challenge is determining which production practices to maintain vs which to simplify for demo scope, while being transparent about those decisions.

---

## Decision

Maintain **production-quality patterns** for:
1. **Anti-injection validation** (core value proposition)
2. **Structured logging** (observability foundation)
3. **Testing practices** (EasyBroker culture alignment)
4. **Clean architecture** (POODR, single responsibility)
5. **Database constraints** (data integrity)

Simplify for demo scope:
1. **No authentication/authorization** (out of scope for lead qualification)
2. **Single database** (no read replicas or sharding)
3. **In-memory scenario management** (vs message queue)
4. **Basic Docker** (no multi-stage builds or orchestration)
5. **No monitoring/APM** (Prometheus, Datadog, etc.)
6. **Simplified search** (ActiveRecord vs Elasticsearch)

---

## Consequences

### Positive
✅ **Clear scope boundaries**: Demo focuses on core value (anti-injection + matching)
✅ **Production patterns demonstrated**: Where it matters for senior evaluation
✅ **Honest trade-offs**: Documented rather than hidden
✅ **Completable timeline**: 6-8 hours is realistic

### Negative
⚠️ **Not directly deployable**: Would need auth, monitoring, scaling for production
⚠️ **Performance limitations**: ActiveRecord search doesn't scale to 500K properties
⚠️ **Single point of failure**: No redundancy or failover

### Mitigations
- **Document production gaps**: Each module guidance includes production considerations
- **Test production patterns**: Even simplified implementations are tested
- **Architecture comments**: Code includes "Production would..." notes where relevant

---

## Production Evolution Path

If this demo were to become production:

### Phase 1: Security & Auth
- Add Devise or custom JWT authentication
- Implement role-based authorization (broker, admin)
- Add API rate limiting and CORS configuration
- Secure secrets management (Rails credentials or Vault)

### Phase 2: Scalability
- Migrate search to Elasticsearch
- Add Redis for caching and session management
- Implement read replicas for database
- Add background job processing (Sidekiq)

### Phase 3: Observability
- Integrate APM (Datadog, New Relic)
- Add Prometheus metrics
- Implement distributed tracing
- Enhanced structured logging with correlation IDs

### Phase 4: Resilience
- Add circuit breakers for LLM calls
- Implement retry logic with exponential backoff
- Database connection pooling optimization
- Multi-region deployment

---

## Demo vs Production Matrix

| Feature | Demo Approach | Production Approach | Rationale |
|---------|---------------|---------------------|-----------|
| **Anti-injection** | LLM + heuristic cross-check | Same + ML anomaly detection | Core value, keep quality |
| **Property search** | ActiveRecord with scopes | Elasticsearch with relevance tuning | Demo scale (<100 properties) |
| **Logging** | Structured JSON to stdout | Same + centralized aggregation | Foundation is production-ready |
| **Testing** | RSpec with >80% coverage | Same + integration/E2E suite | Culture alignment |
| **Authentication** | None (out of scope) | JWT + role-based auth | Not needed for demo |
| **LLM client** | Direct Anthropic API call | Retry + circuit breaker + fallback | Simplify for demo |
| **Database** | Single PostgreSQL | Primary + read replicas | Demo doesn't need scale |
| **Deployment** | Docker Compose | Kubernetes + multi-region | Local dev sufficient |
| **Monitoring** | Health check endpoint | Full APM + alerting | Observable enough for demo |
| **Error handling** | Structured exceptions | Same + error tracking (Sentry) | Pattern is production-ready |

---

## Alignment with EasyBroker Culture

### Maintained Values
✅ **Clean Code**: Single responsibility, descriptive naming
✅ **Testing**: Comprehensive RSpec coverage
✅ **Refactoring**: Iterative commits showing evolution
✅ **Product thinking**: Focus on business value over tech complexity

### Documented Gaps
- "We do pair programming" → Solo demo with documented thought process
- "We use Elasticsearch" → ActiveRecord with production migration path noted
- "Continuous deployment" → Docker setup demonstrates environment management

---

## References

- EasyBroker tech stack: Rails 7, MySQL, Elasticsearch, Redis
- EasyBroker culture: Clean Code, POODR, heavy testing
- Demo scope: Blueprint.md Módulo 0-7
- Learning log: Captures implementation challenges

---

**Review Trigger**: Before final demo submission
**Owner**: Project lead
**Last Updated**: 2025-12-20
