# Demo Setup Guide

## Prerequisites

Before running demos, ensure the database is seeded with properties.

### Step 1: Start Docker Containers

```bash
docker compose up -d
```

### Step 2: Seed Database

**CRITICAL**: You must seed the database to have properties for matching:

```bash
docker compose run --rm app rails db:seed
```

**Expected Output:**
```
Cleaning database...
Creating properties...
Created 26 properties
  CDMX: 12
  Guadalajara: 8
  Monterrey: 6
Created sample conversation session with 5 messages
```

### Step 3: Verify Seeds

Check that properties exist:

```bash
docker compose run --rm app rails runner 'puts "Total properties: #{Property.count}"'
```

Should output: `Total properties: 26`

### Step 4: Access Dashboard

Navigate to: http://localhost:3001

---

## Testing Pre-Defined Scenarios

### Scenario 1: Budget Seeker (Happy Path)

**Test via Dashboard:**
1. Click "Scenario 1: Budget Seeker" button
2. Should show:
   - ✅ Lead Qualified Successfully
   - 🏠 **3 Property Matches** (CDMX, Roma Norte area)
   - Budget: 3,000,000
   - City: CDMX
   - Area: Roma Norte
   - Bedrooms: 2

**Expected Matches:**
- Departamento en Roma Norte (~2.55M, score: 80)
- Casa en Roma Norte (~2.56M, score: 80)
- Departamento en Condesa (~2.29M, score: 60)

**Test via cURL:**
```bash
curl -X POST http://localhost:3001/run \
  -H "X-Scenario: budget_seeker" \
  -H "Content-Type: application/json"
```

---

### Scenario 2: Budget Mismatch (Anti-Injection)

**Test via Dashboard:**
1. Click "Scenario 2: Budget Mismatch" button
2. Should show:
   - ⚠️ **Human Review Required**
   - Discrepancy Alert (budget: 66.7% difference)
   - LLM: 5,000,000
   - Heuristic: 3,000,000
   - Still generates property matches (Guadalajara)

**Test via cURL:**
```bash
curl -X POST http://localhost:3001/run \
  -H "X-Scenario: budget_mismatch" \
  -H "Content-Type: application/json"
```

---

### Scenario 3: Phone vs Budget

**Test via Dashboard:**
1. Click "Scenario 3: Phone vs Budget" button
2. Should show:
   - ✅ No Discrepancy
   - Heuristic correctly ignores phone number
   - Property matches (Monterrey)

---

## Testing Custom Messages

### With FakeClient (No API Key)

1. Paste JSON into "Custom Messages" textarea
2. Leave "Use Real Anthropic API" **unchecked**
3. Click "Run Custom Messages"
4. System uses simulated LLM extraction

**Example:**
```json
[
  {"role": "user", "content": "Busco casa en Guadalajara, presupuesto 4 millones"}
]
```

### With Real API (Requires API Key)

1. Add API key to `.env`:
   ```bash
   ANTHROPIC_API_KEY=sk-ant-your-key-here
   ```

2. Restart containers:
   ```bash
   docker compose restart app
   ```

3. Check "Use Real Anthropic API" checkbox
4. Run custom messages

---

## Property Availability Reference

### CDMX (12 properties)
- **Areas:** Roma Norte, Condesa, Polanco, Del Valle, Coyoacán, Santa Fe
- **Price Range:** 2M - 8M
- **Bedrooms:** 2-4

### Guadalajara (8 properties)
- **Areas:** Providencia, Chapalita, Zapopan, Tlaquepaque
- **Price Range:** 1.5M - 6M
- **Bedrooms:** 2-4

### Monterrey (6 properties)
- **Areas:** San Pedro, Cumbres, Valle Oriente
- **Price Range:** 2.5M - 9M
- **Bedrooms:** 2-4

---

## Troubleshooting

### "No matching properties found"

**Cause:** Database not seeded

**Fix:**
```bash
docker compose run --rm app rails db:seed
```

### Empty Matches Array (valid)

This is expected when:
- ❌ City not in database (Puebla, Querétaro)
- ❌ Budget too far from property range (>30% difference)
- ❌ No properties match criteria

### API Key Not Working

1. Verify key in `.env` file
2. Restart containers: `docker compose restart app`
3. Check logs: `docker compose logs app | grep ANTHROPIC`

### Container Issues

Rebuild containers:
```bash
docker compose down
docker compose build
docker compose up -d
docker compose run --rm app rails db:seed
```

---

## Demo Flow Recommendation

### Quick Demo (5 minutes)

1. **Show Happy Path** - Scenario 1 (Budget Seeker)
   - ✅ 3 property matches
   - Shows extraction + matching working

2. **Show Anti-Injection** - Scenario 2 (Budget Mismatch)
   - ⚠️ Discrepancy alert
   - Still generates matches (robust system)

3. **Show Edge Case** - Custom: Wrong city (Puebla)
   - Empty matches (validates city)

### Full Demo (15 minutes)

1. All 3 pre-defined scenarios
2. Custom message with contradiction
3. Custom message with real API
4. Show extraction process transparency
5. Explain scoring algorithm

---

## API Testing Examples

### Test All Scenarios

```bash
# Budget Seeker
curl -X POST http://localhost:3001/run -H "X-Scenario: budget_seeker" -H "Content-Type: application/json" | jq '.matches | length'

# Budget Mismatch
curl -X POST http://localhost:3001/run -H "X-Scenario: budget_mismatch" -H "Content-Type: application/json" | jq '.needs_human_review'

# Phone vs Budget
curl -X POST http://localhost:3001/run -H "X-Scenario: phone_vs_budget" -H "Content-Type: application/json" | jq '.discrepancies'
```

### Test Custom Messages

```bash
curl -X POST http://localhost:3001/run \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "Busco departamento en CDMX, presupuesto 5 millones"}
    ]
  }' | jq '.matches'
```

---

## Success Criteria

After setup, you should be able to:
- ✅ Run all 3 pre-defined scenarios
- ✅ Get 3 property matches for "budget_seeker"
- ✅ See discrepancy alert for "budget_mismatch"
- ✅ Test custom messages with simulated LLM
- ✅ Test custom messages with real API (if key configured)
- ✅ See extraction process transparency
- ✅ Observe property matching scores

Total expected properties: **26**
Expected match rate: ~80% for valid city/budget combinations
