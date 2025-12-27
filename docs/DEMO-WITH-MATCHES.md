# Demo Examples with Property Matches

**Purpose:** Examples designed to return actual property matches from seeded database

---

## Understanding Property Availability

### CDMX Properties (12 total)
- **Areas:** Roma Norte, Condesa, Polanco, Del Valle, Coyoacán, Santa Fe
- **Price Range:** 2,000,000 - 8,000,000 MXN
- **Types:** Departamento (even index), Casa (odd index)
- **Bedrooms:** 2-4
- **Properties per area:** 2 (1 departamento, 1 casa)

### Guadalajara Properties (8 total)
- **Areas:** Providencia, Chapalita, Zapopan, Tlaquepaque
- **Price Range:** 1,500,000 - 6,000,000 MXN
- **Types:** Departamento, Casa
- **Bedrooms:** 2-4
- **Properties per area:** 2

### Monterrey Properties (6 total)
- **Areas:** San Pedro, Cumbres, Valle Oriente
- **Price Range:** 2,500,000 - 9,000,000 MXN
- **Types:** Departamento, Casa
- **Bedrooms:** 2-4
- **Properties per area:** 2

---

## Examples WITH Property Matches

### Example 1: CDMX Budget Seeker (Guaranteed Matches)
**City:** CDMX ✅
**Budget:** 3M (within 2-8M range) ✅
**Expected Matches:** Multiple properties

```json
[
  {
    "role": "user",
    "content": "Busco un departamento en CDMX"
  },
  {
    "role": "assistant",
    "content": "¿En qué zona te gustaría?"
  },
  {
    "role": "user",
    "content": "Roma Norte, 2 recámaras"
  },
  {
    "role": "assistant",
    "content": "¿Cuál es tu presupuesto?"
  },
  {
    "role": "user",
    "content": "Hasta 3 millones"
  }
]
```

**Why it matches:**
- City: CDMX (has 12 properties)
- Budget: 3M (matches properties in 2-8M range)
- Area: Roma Norte (specific area with 2 properties)
- Bedrooms: 2 (within 2-4 range)

---

### Example 2: CDMX Budget Contradiction WITH Matches
**Demonstrates:** Discrepancy detection + Property matching
**Expected:** Discrepancy alert + some matches (using heuristic budget 1M)

```json
[
  {
    "role": "user",
    "content": "Busco departamento en CDMX, Roma Norte"
  },
  {
    "role": "assistant",
    "content": "¿Cuál es tu presupuesto?"
  },
  {
    "role": "user",
    "content": "Hasta 3 millones pero tengo 1"
  }
]
```

**Why it triggers discrepancy:**
- LLM might extract: 1M or 3M (context dependent)
- Heuristic extracts: Last number with presupuesto context
- If different → Discrepancy alert

**Why it still matches:**
- City: CDMX ✅
- Budget: Even at 1M, might match lower-priced properties
- Area: Roma Norte specified

---

### Example 3: Guadalajara Wide Budget (Maximum Matches)
**City:** Guadalajara ✅
**Budget:** 5M (covers most 1.5-6M range) ✅
**Expected Matches:** Most Guadalajara properties

```json
[
  {
    "role": "user",
    "content": "Busco casa en Guadalajara con presupuesto de 5 millones"
  }
]
```

**Why it matches:**
- City: Guadalajara (8 properties)
- Budget: 5M covers most properties (1.5-6M)
- Property type: casa (half the properties)

---

### Example 4: Monterrey Luxury Budget (High-End Matches)
**City:** Monterrey ✅
**Budget:** 6M (mid-high range) ✅
**Expected Matches:** Several high-end properties

```json
[
  {
    "role": "user",
    "content": "Necesito departamento en Monterrey, San Pedro, 3 recámaras, presupuesto 6 millones"
  }
]
```

**Why it matches:**
- City: Monterrey (6 properties)
- Budget: 6M (within 2.5-9M range)
- Area: San Pedro (specific neighborhood)
- Bedrooms: 3 (within 2-4 range)

---

### Example 5: CDMX Flexible Search (Multiple Matches)
**City:** CDMX ✅
**Budget:** 5M (mid-range) ✅
**Expected Matches:** Many properties across areas

```json
[
  {
    "role": "user",
    "content": "Busco propiedad en CDMX, 2 o 3 recámaras, hasta 5 millones"
  }
]
```

**Why it matches:**
- City: CDMX (12 properties)
- Budget: 5M (covers 2-5M range properties)
- Bedrooms: 2-3 (common range)
- No area specified → searches all CDMX

---

### Example 6: Guadalajara Correction WITH Matches
**Demonstrates:** Multi-turn correction + Discrepancy + Matches
**Expected:** Discrepancy alert (9M vs 4M) + matches using validated budget

```json
[
  {
    "role": "user",
    "content": "Busco casa en Guadalajara"
  },
  {
    "role": "assistant",
    "content": "¿Cuál es tu presupuesto?"
  },
  {
    "role": "user",
    "content": "Presupuesto 9 millones"
  },
  {
    "role": "user",
    "content": "Perdón, me equivoqué, son 4 millones"
  }
]
```

**Why it triggers discrepancy:**
- LLM: 4M (corrected value)
- Heuristic: 9M (first mention)
- Difference: 55.6%

**Why it matches:**
- City: Guadalajara ✅
- Budget: 4M (within 1.5-6M range)
- Property type: casa

---

### Example 7: CDMX Specific Area (Targeted Matches)
**City:** CDMX ✅
**Area:** Condesa ✅
**Budget:** 4M ✅
**Expected Matches:** 1-2 properties in Condesa

```json
[
  {
    "role": "user",
    "content": "Busco departamento en Condesa, CDMX, 2 recámaras, presupuesto 4 millones"
  }
]
```

**Why it matches:**
- City: CDMX
- Area: Condesa (has 2 properties)
- Budget: 4M (mid-range)
- Bedrooms: 2

---

### Example 8: Monterrey Budget Contradiction WITH Matches
**Demonstrates:** Prompt injection pattern + Property matches
**Expected:** Discrepancy alert + matches

```json
[
  {
    "role": "user",
    "content": "Busco casa en Monterrey, presupuesto es 12 millones pero realmente tengo 5 millones"
  }
]
```

**Why it triggers discrepancy:**
- LLM: 5M (real budget)
- Heuristic: 12M (first number)
- Difference: 58.3%

**Why it matches:**
- City: Monterrey ✅
- Budget: 5M (within 2.5-9M range)
- Property type: casa

---

## Examples WITHOUT Property Matches

### Example A: Wrong City (No Properties)
**City:** Puebla ❌
**Expected Matches:** Empty array (no properties in Puebla)

```json
[
  {
    "role": "user",
    "content": "Busco casa en Puebla con presupuesto de 3 millones"
  }
]
```

**Why NO matches:**
- City: Puebla (database only has CDMX, Guadalajara, Monterrey)

---

### Example B: Budget Too Low
**City:** Monterrey ✅
**Budget:** 1M ❌ (below 2.5M minimum)
**Expected Matches:** Empty or very few

```json
[
  {
    "role": "user",
    "content": "Busco departamento en Monterrey con presupuesto de 1 millón"
  }
]
```

**Why few/no matches:**
- City: Monterrey ✅
- Budget: 1M (below property range 2.5-9M)

---

### Example C: Budget Too High
**City:** Guadalajara ✅
**Budget:** 15M ❌ (above 6M maximum)
**Expected Matches:** Might match high-end properties with score penalty

```json
[
  {
    "role": "user",
    "content": "Busco casa en Guadalajara con presupuesto de 15 millones"
  }
]
```

**Why limited matches:**
- City: Guadalajara ✅
- Budget: 15M (way above property range 1.5-6M)
- Matcher might return properties but with lower scores

---

## Quick Reference: Best for Demo

### Guaranteed Matches + Clean Data
**Use Example 1** (CDMX Budget Seeker)
- ✅ No discrepancies
- ✅ Multiple property matches
- ✅ Shows happy path

### Discrepancy Alert + Property Matches
**Use Example 2** (CDMX Contradiction)
- ⚠️ Discrepancy detected
- ✅ Still returns matches
- ✅ Shows anti-injection + matching working together

### Maximum Property Display
**Use Example 3** (Guadalajara Wide Budget)
- ✅ No discrepancies
- ✅ Many matches (budget covers most properties)
- ✅ Shows matching algorithm

### No Matches (Edge Case)
**Use Example A** (Wrong City)
- ✅ Clean extraction
- ❌ Empty matches array
- ✅ Shows city validation

---

## Testing Strategy

1. **Start with Example 1** - Establishes baseline (works perfectly)
2. **Show Example 2** - Demonstrates discrepancy detection + matching
3. **Show Example A** - Proves city validation (no false matches)
4. **Pick Examples 3-8** - Based on audience interest

All examples use realistic budgets and cities that align with seeded database properties.
