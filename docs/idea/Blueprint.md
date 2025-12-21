# EasyBroker Demo Project - Blueprint Ejecutivo

**Fecha**: Diciembre 2025
**Proyecto**: Smart Property Matching Assistant
**Objetivo**: Demo técnico Senior Ruby on Rails Engineer para EasyBroker
**Metodología**: Desarrollo humano-dirigido con IA supervisada y documentación transparente

---

## Resumen Ejecutivo

## Scope: Lead Qualification Engine

This demo implements **step 2** of EasyBroker's lead qualification flow:

1. Lead sends message via WhatsApp/web → **OUT OF SCOPE**
2. **Message processed by qualification system** → **THIS DEMO**
3. Broker reviews results in dashboard → **OUT OF SCOPE**
4. Broker contacts lead with properties → **OUT OF SCOPE**

**Focus**: Anti-injection extraction + property matching + observability

### Valor Técnico del Demo
- **Anti-injection system**: Cross-validation LLM vs heurístico con evidencia observable
- **Domain expertise**: Comprensión profunda del negocio inmobiliario mexicano
- **Architectural thinking**: 9 problemas identificados antes de codificar
- **Transparent AI methodology**: Proceso documentado de supervisión técnica

---

## Arquitectura Central

### Core Components
```
Smart Property Matching Assistant
│
├── ConversationSession
│   ├── lead_profile (jsonb) - Perfil extraído del lead
│   ├── discrepancies (jsonb[]) - Evidencia de cross-check
│   ├── needs_human_review (boolean) - Flag de revisión
│   └── qualification_duration_ms - Métricas de performance
│
├── LeadQualifier (anti-injection engine)
│   ├── extract_from_llm() - Extracción vía Claude API
│   ├── extract_heuristic() - Validación regex defensiva
│   └── compare_profiles() - Detecta manipulación/inconsistencias
│
├── PropertyMatcher (business logic)
│   ├── city_filter() - Ciudad obligatoria para matching
│   ├── score_properties() - Algoritmo de scoring con razones
│   └── format_results() - Top 3 matches con explicaciones
│
└── Minimal Interface
    ├── Scenario selector - 3 botones para demo
    ├── Results display - Lead + matches + discrepancies
    └── Anti-injection alert - Visual evidence cuando aplique
```

### API Flow
```
POST /run + X-Scenario header
  ↓
Load scenario messages
  ↓
LeadQualifier.call(session)
  ├── LLM extraction
  ├── Heuristic extraction
  ├── Cross-validation
  └── Discrepancy detection
  ↓
PropertyMatcher.call(profile) if city present
  ↓
JSON response with evidence
```

---

## Metodología de IA Transparente

### Infraestructura de Gobernanza
```
📁 .agent/
├── context.md - Contexto principal para Claude Code
├── context-routes.yaml - Routing de documentación por módulo
└── governance.md - Reglas para documentación y desarrollo

📁 docs/
├── ai-guidance/ - Guías específicas por módulo (7 archivos)
├── architecture/ - ADRs y trade-offs Production vs Demo
└── learning-log/ - Challenges y iteraciones arquitectónicas
```

### Principios de Desarrollo
1. **Human-directed execution**: IA ejecuta, humano supervisa arquitectura
2. **Transparent process**: Todo guidance documentado y auditable
3. **Learning documented**: Challenges y decisiones capturadas
4. **Quality gates**: Tests y checklist por módulo

### Señal Técnica para EasyBroker
- **Process maturity**: Governance framework demuestra sistematización
- **Architectural control**: Learning log prueba criterio técnico independiente
- **Documentation culture**: Compatible con valores EasyBroker
- **Not AI-dependency**: Methodology shows human oversight

---

## Plan Modular (7 módulos + 6-8 horas)

### **Módulo 0: AI Infrastructure** (30 min)
- Agent configuration y routing
- Governance framework
- Module guidance templates

### **Módulo 1: Foundation** (45 min)
- Rails 7 API + PostgreSQL + Docker
- RSpec setup + structured logging
- Health check endpoint

### **Módulo 2: Domain Models** (1 hora)
- ConversationSession, Property, Message models
- Seeds con 30 propiedades CDMX/Guadalajara/Monterrey
- Índices para performance

### **Módulo 3: LLM Adapter** (1 hora)
- CurrentAttributes para scenarios
- FakeClient con 3 scenarios + AnthropicClient real
- Thread-safe scenario management

### **Módulo 4: Anti-Injection Core** (2.5 horas) ⭐ **CRÍTICO**
- LeadQualifier service completo
- Cross-validation LLM vs heurístico
- discrepancies[] population
- Edge case: phone vs budget extraction

### **Módulo 5: Property Matching** (1 hora)
- PropertyMatcher con scoring
- Prefiltro SQL para performance
- Ciudad obligatoria enforcement

### **Módulo 6: API Endpoint** (1.5 horas)
- POST /run endpoint completo
- Error handling robusto
- Response structure final

### **Módulo 7: Minimal Interface** (1 hora)
- Turbo Rails simple dashboard
- 3 scenario buttons + results display
- Visual evidence de anti-injection

---

## Casos de Prueba Críticos

### Escenarios Obligatorios
1. **budget_seeker** (happy path)
   - Input: "Busco depa 3 millones Roma Norte CDMX"
   - Expected: discrepancies=[], review=false, matches found

2. **budget_mismatch** (anti-injection)
   - LLM extrae: 5M, Heurístico encuentra: 3M
   - Expected: discrepancies=[{field:'budget', diff_pct:66.7}], review=true

3. **phone_vs_budget** (edge case)
   - Input: "presupuesto 3 millones, mi tel 5512345678"
   - Expected: budget=3000000, NO 5512345678

### Response Esperado
```json
{
  "session_id": "abc123",
  "lead_profile": {
    "budget": 3000000,
    "city": "CDMX",
    "area": "Roma Norte",
    "beds": 2,
    "confidence": "high"
  },
  "matches": [
    {
      "id": 12,
      "title": "Depa Roma Norte 2 rec",
      "price": 2950000,
      "score": 65,
      "reasons": ["budget_exact_match", "area_match"]
    }
  ],
  "needs_human_review": false,
  "discrepancies": [],
  "metrics": {
    "qualification_duration_ms": 234,
    "turns_count": 5
  }
}
```

---

## Constraints No Negociables

### Técnicos
- ✅ Rails 7 API mode (NO session middleware)
- ✅ PostgreSQL con jsonb (constraint explícito documentado)
- ✅ CurrentAttributes (NEVER Thread.current)
- ✅ Structured JSON logging a stdout
- ✅ Anti-injection obligatorio con discrepancies[]
- ✅ RSpec tests para edge cases críticos

### Arquitectónicos
- ✅ discrepancies[] como array desde el inicio (no || [])
- ✅ Ciudad obligatoria para property matching
- ✅ Budget extraction que distingue teléfonos
- ✅ LLM fallback graceful (timeout → heurístico)
- ✅ Logging de eventos con métricas

### Metodológicos
- ✅ Cada commit funcional y reversible
- ✅ Tests antes de implementation
- ✅ Guidance documentado por módulo
- ✅ Learning log actualizado cuando hay challenges

---

## Deliverables Finales

### Código
- ✅ API funcional con endpoint /run
- ✅ Interfaz mínima para demo visual
- ✅ Tests comprehensivos (>80% coverage)
- ✅ Docker setup para reproducibilidad

### Documentación
- ✅ README con arquitectura + trade-offs
- ✅ AI guidance completo (7 módulos)
- ✅ Learning log con challenges reales
- ✅ Architecture decisions (ADRs)

### Evidencia Observable
- ✅ discrepancies[] en responses cuando aplique
- ✅ Logs JSON estructurados en stdout
- ✅ Commits naturales con mensajes descriptivos
- ✅ Test coverage visible

---

## Criterios de Éxito

### Técnicos
- [ ] `curl -H "X-Scenario: budget_seeker" POST /run` funciona
- [ ] `curl -H "X-Scenario: budget_mismatch" POST /run` retorna discrepancies
- [ ] Tests pasan: `rspec spec/`
- [ ] Logs muestran JSON estructurado
- [ ] Interface muestra anti-injection visualmente

### Metodológicos
- [ ] Toda AI guidance documentada y referenciada
- [ ] Learning log con challenges reales (no ficticio)
- [ ] Architecture decisions documentadas
- [ ] Commits muestran desarrollo iterativo natural

### De Negocio (EasyBroker specific)
- [ ] Demo relevante al dominio inmobiliario
- [ ] Anti-injection muestra pensamiento defensivo
- [ ] Process transparencia demuestra control técnico
- [ ] Scope realista para 7-8 horas desarrollo

---

## Valor para Postulación EasyBroker

### Alineamiento Cultural
1. **Clean Code + POODR**: Módulos pequeños, responsabilidad única
2. **Testing culture**: RSpec comprehensivo desde el inicio
3. **Refactoring mindset**: Iteraciones documentadas
4. **Product thinking**: Domain-relevant sobre technical complexity

### Diferenciación Competitiva
1. **Relevancia directa**: Property matching vs generic Rails demo
2. **Senior thinking**: Preventive architecture, edge cases anticipados
3. **Transparent AI**: Process maduro, no black box dependency
4. **Observable evidence**: Technical decisions visible en outputs

### Risk Mitigation
1. **AI framing**: Tool para productivity, no replacement de skill
2. **Technical depth**: Learning log prueba comprensión profunda
3. **Domain knowledge**: Seeds y business logic muestran research
4. **Quality process**: Governance compatible con cultura EasyBroker

---

## Next Steps

1. **Setup inicial**: Crear estructura de archivos + .agent configuration
2. **AI guidance**: Escribir los 7 archivos de guidance por módulo
3. **Development**: Seguir plan modular con commits naturales
4. **Documentation**: Actualizar learning log durante desarrollo
5. **Final review**: Validar que todos los criterios se cumplen

---

**Tags**: #easybroker #rails-demo #ai-transparency #anti-injection #property-matching #senior-engineer
