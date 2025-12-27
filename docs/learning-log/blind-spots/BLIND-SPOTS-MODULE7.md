# Module 7 Blind Spots Analysis

**Date**: 2025-12-27
**Module**: Minimal Interface (Turbo Dashboard)
**Review Type**: During-implementation analysis
**Status**: 🔴 2 CRITICAL blind spots discovered

---

## Summary

Module 7 implementation discovered **2 CRITICAL blind spots** and **1 DESIGN blind spot** that significantly impact demo value.

**Key Discovery**: Pre-implementation review caught API vs Base pattern but MISSED the bigger issue - demo doesn't show anti-injection evidence.

---

## Blind Spots Discovered

### 🔴 CRÍTICO #1: ActionController::API vs Base

**Issue**: DashboardController inherited from ApplicationController (ActionController::API) which doesn't support HTML views.

**Code Location**: `app/controllers/dashboard_controller.rb:1`

**Discovery Method**: Immediate - curl returned `204 No Content` instead of HTML

**Problem**:
```ruby
# INITIAL (WRONG):
class ApplicationController < ActionController::API
  # ...
end

class DashboardController < ApplicationController
  def index
    # Rails tries to render view but API mode doesn't support it
    # → 204 No Content
  end
end
```

**Why Missed in Pre-Implementation Review**:
- Checked `health_controller.rb` - it's API-only (JSON response)
- Checked `runs_controller.rb` - it's API-only (JSON response)
- NO existing controller with HTML views to use as pattern
- Module 7 is FIRST module to need ActionController::Base

**Impact**: 🔴 **CRITICAL** (but caught immediately)
- Dashboard returned 204 No Content
- No HTML rendered
- Easy to detect via curl/browser

**Fix Applied**:
```ruby
# CORRECT:
class DashboardController < ActionController::Base  # Not ApplicationController
  def index
    # Now renders HTML view correctly ✅
  end
end
```

**Resolution**: ✅ FIXED (within 5 minutes)
- Changed inheritance to ActionController::Base
- Restarted Rails
- Dashboard loaded successfully

**Lesson Learned**:
> When existing patterns DON'T match your use case (API vs HTML), you must deviate from the pattern. Rails API mode ≠ Rails with views.

---

### 🔴 CRÍTICO #2: Demo Shows Result, Not Process

**Issue**: Dashboard displays final `lead_profile` and `discrepancies`, but NOT the extraction process that generates them.

**Code Location**: `app/views/dashboard/index.html.erb:220-308` (displayResults function)

**Discovery Method**: User feedback - "No hay transparencia, los escenarios parecen estáticos"

**Problem**:

**What the demo SHOWS**:
```javascript
// Final results only
✅ Lead Profile: { budget: 3000000, city: "CDMX", ... }
✅ Discrepancies: [{ field: "budget", diff_pct: 40, ... }]
✅ Property Matches: [...]
```

**What the demo DOES NOT SHOW**:
```javascript
❌ Conversation messages sent to LLM
❌ LLM raw response (JSON extraction)
❌ Heuristic extraction process (regex patterns)
❌ Cross-validation step-by-step
❌ System prompt used
❌ Whether FakeClient or real API was used
```

**Why This is Critical**:

The **core value proposition** is:
> Anti-injection via dual extraction (LLM + heuristic) with cross-validation

But the demo shows:
- Just the final merged profile ❌
- Just discrepancies (if any) ❌
- No evidence of HOW anti-injection works ❌

**Impact**: 🔴 **CRITICAL DESIGN FLAW**
- Demo doesn't demonstrate the anti-injection methodology
- Looks like static scenarios (which they ARE via FakeClient)
- No transparency into the dual extraction process
- Evaluators can't see the core innovation

**User Concerns (Valid)**:
1. "¿El demo hace peticiones a Claude API?" - No, usa FakeClient (not obvious)
2. "¿Es posible ver qué se envía?" - No (blind spot)
3. "¿No sería más útil mostrar lo que se envía y respuesta?" - YES! (blind spot)
4. "Los escenarios parecen estáticos" - Correct observation (design issue)
5. "No es posible hacer pruebas custom" - True (limitation)

**Root Cause**:
- Guidance focused on "display results" not "show methodology"
- Module 7 guidance (07-minimal-interface.md) has minimal requirements
- No emphasis on transparency or educational value
- Demo treats anti-injection as black box

**Resolution**: ✅ **RESOLVED** - Opción B fully implemented with all checkpoints complete

---

### 🟡 IMPORTANTE #3: No Way to Test Custom Scenarios

**Issue**: Dashboard has 3 hardcoded scenario buttons, no way to input custom messages.

**Code Location**: `app/views/dashboard/index.html.erb:180-193` (scenario buttons)

**Current Implementation**:
```html
<!-- Only 3 scenarios -->
<button onclick="runScenario('budget_seeker')">Scenario 1</button>
<button onclick="runScenario('budget_mismatch')">Scenario 2</button>
<button onclick="runScenario('phone_vs_budget')">Scenario 3</button>
```

**Missing**:
```html
<!-- No custom input -->
❌ <textarea>Enter your own messages...</textarea>
❌ <button>Run Custom Scenario</button>
```

**Impact**: 🟡 **IMPORTANTE**
- Can't test other prompt injection attempts
- Can't demonstrate flexibility
- Limited to 3 pre-defined cases
- Evaluators can't experiment

**Resolution**: ✅ **RESOLVED** - Opción B implemented successfully (Checkpoints 1-7 complete)

---

## Opción B Implementation Plan

### Objectives

1. **Show Extraction Process Transparency**
   - Display conversation messages
   - Show LLM extraction (from FakeClient or real API)
   - Show heuristic extraction (regex results)
   - Show cross-validation comparison

2. **Enable Custom Message Input**
   - Textarea for user to write messages
   - POST messages to `/run` endpoint
   - Support both FakeClient and real API

3. **Environment-Based API Toggle**
   - `USE_REAL_API=true` → Use Anthropic API (requires `ANTHROPIC_API_KEY`)
   - `USE_REAL_API=false` → Use FakeClient (default)

---

## Implementation Checkpoints

### Checkpoint 1: Document Current State ✅
- [x] Document blind spot #1 (ActionController::API)
- [x] Document blind spot #2 (No process transparency)
- [x] Document blind spot #3 (No custom input)
- [x] Create implementation plan

### Checkpoint 2: Modify RunsController to Return Extraction Details
**Goal**: Include `llm_extraction`, `heuristic_extraction`, `messages` in response

**Changes needed**:
```ruby
# app/controllers/runs_controller.rb
def create
  session = create_session_with_messages

  # Capture extraction details BEFORE qualification
  extraction_details = capture_extraction_process(session)

  qualify_lead(session)
  matches = match_properties(session)

  render json: format_response(session, matches, extraction_details), status: :ok
end

private

def capture_extraction_process(session)
  # Return: messages, llm_response, heuristic_response
end

def format_response(session, matches, extraction_details)
  {
    session_id: session.id,
    lead_profile: session.lead_profile,
    matches: matches,
    needs_human_review: session.needs_human_review,
    discrepancies: session.discrepancies,
    metrics: { ... },
    status: session.status,

    # NEW: Transparency data
    extraction_process: extraction_details
  }
end
```

**Commit**: `[Module7] Add extraction process details to API response`

### Checkpoint 3: Update LeadQualifier to Return Extraction Data
**Goal**: Make LeadQualifier return extraction details, not just update session

**Changes needed**:
```ruby
# app/services/lead_qualifier.rb
def call
  @start_time = Time.current

  llm_profile = extract_from_llm
  heuristic_profile = extract_from_heuristic

  # ... existing cross-validation logic ...

  @session.tap(&:save!)

  # NEW: Return extraction details
  {
    session: @session,
    llm_extraction: llm_profile,
    heuristic_extraction: heuristic_profile,
    messages: @session.messages.ordered.map { |m| { role: m.role, content: m.content } }
  }
end
```

**Commit**: `[Module7] Modify LeadQualifier to return extraction details`

### Checkpoint 4: Add Environment-Based API Toggle
**Goal**: Allow switching between FakeClient and real API via ENV variable

**Changes needed**:
```ruby
# app/services/llm/fake_client.rb
def self.should_use_real_api?
  ENV['USE_REAL_API'] == 'true' && ENV['ANTHROPIC_API_KEY'].present?
end

def extract_profile(messages)
  if self.class.should_use_real_api? && !Current.scenario
    # Use real Anthropic API
    AnthropicClient.new.extract_profile(messages)
  elsif Current.scenario && SCENARIOS.key?(Current.scenario)
    # Use FakeClient scenario
    SCENARIOS[Current.scenario][:llm_response]
  else
    # Fallback to AnthropicClient
    AnthropicClient.new.extract_profile(messages)
  end
end

def self.scenario_messages(scenario)
  if should_use_real_api?
    # Return empty to force real API call
    []
  else
    SCENARIOS[scenario][:messages]
  end
end
```

**Commit**: `[Module7] Add USE_REAL_API environment variable toggle`

### Checkpoint 5: Update Dashboard View - Transparency Section
**Goal**: Show extraction process in expandable section

**Changes needed**:
```javascript
// app/views/dashboard/index.html.erb
function displayResults(data, scenario) {
  // ... existing code ...

  // NEW: Extraction Process Transparency
  if (data.extraction_process) {
    html += '<h2>🔍 Extraction Process (Anti-Injection Evidence)</h2>';

    html += '<details open>';
    html += '<summary><strong>1. Conversation Messages</strong></summary>';
    html += '<pre class="json-view">' + JSON.stringify(data.extraction_process.messages, null, 2) + '</pre>';
    html += '</details>';

    html += '<details>';
    html += '<summary><strong>2. LLM Extraction</strong></summary>';
    html += '<pre class="json-view">' + JSON.stringify(data.extraction_process.llm_extraction, null, 2) + '</pre>';
    html += '</details>';

    html += '<details>';
    html += '<summary><strong>3. Heuristic Extraction (Defensive)</strong></summary>';
    html += '<pre class="json-view">' + JSON.stringify(data.extraction_process.heuristic_extraction, null, 2) + '</pre>';
    html += '</details>';

    html += '<details>';
    html += '<summary><strong>4. Cross-Validation</strong></summary>';
    if (data.discrepancies.length > 0) {
      html += '<p>⚠️ Discrepancies found - triggering human review</p>';
    } else {
      html += '<p>✅ No discrepancies - extractions match</p>';
    }
    html += '</details>';
  }

  // ... rest of existing code ...
}
```

**Commit**: `[Module7] Add extraction process transparency section to dashboard`

### Checkpoint 6: Add Custom Message Input
**Goal**: Allow users to write custom messages and test them

**Changes needed**:
```html
<!-- After scenario buttons -->
<div class="custom-input">
  <h3>Or Test Custom Messages</h3>
  <textarea id="customMessages" rows="6" placeholder='[
  {"role": "user", "content": "Busco casa en CDMX, presupuesto 5 millones"},
  {"role": "assistant", "content": "¿Cuántas recámaras necesitas?"},
  {"role": "user", "content": "3 recámaras"}
]'></textarea>
  <button class="scenario-btn" onclick="runCustomScenario()">
    Run Custom Messages
  </button>
  <label>
    <input type="checkbox" id="useRealAPI"> Use Real Anthropic API (requires API key in .env)
  </label>
</div>
```

```javascript
async function runCustomScenario() {
  const customMessages = document.getElementById('customMessages').value;
  const useRealAPI = document.getElementById('useRealAPI').checked;

  try {
    const messages = JSON.parse(customMessages);

    const response = await fetch('/run', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Use-Real-API': useRealAPI ? 'true' : 'false'
      },
      body: JSON.stringify({ messages: messages })
    });

    const data = await response.json();
    displayResults(data, 'custom');
  } catch (error) {
    alert('Invalid JSON: ' + error.message);
  }
}
```

**Commit**: `[Module7] Add custom message input functionality`

### Checkpoint 7: Update RunsController to Accept Messages in Body
**Goal**: Support custom messages from request body

**Changes needed**:
```ruby
# app/controllers/runs_controller.rb
def create_session_with_messages
  session = ConversationSession.create!

  messages = if params[:messages].present?
               # Custom messages from request body
               params[:messages]
             elsif Current.scenario
               # FakeClient scenario
               LLM::FakeClient.scenario_messages(Current.scenario)
             else
               # No messages
               []
             end

  messages.each_with_index do |msg, index|
    session.messages.create!(
      role: msg[:role] || msg['role'],
      content: msg[:content] || msg['content'],
      sequence_number: index
    )
  end

  session.update!(turns_count: messages.size)
  session
end

private

def set_use_real_api
  ENV['USE_REAL_API'] = request.headers['X-Use-Real-API'] if request.headers['X-Use-Real-API'].present?
end
```

**Commit**: `[Module7] Support custom messages in request body`

### Checkpoint 8: Update Documentation
**Goal**: Document how to use real API and custom messages

**Create**: `docs/DEMO-USAGE.md`
```markdown
# Demo Usage Guide

## Using FakeClient (Default)

Click any scenario button - uses pre-defined messages.

## Using Real Anthropic API

1. Set environment variable:
   ```bash
   USE_REAL_API=true
   ANTHROPIC_API_KEY=sk-ant-...
   ```

2. Check "Use Real Anthropic API" checkbox
3. Enter custom messages or click scenario button

## Custom Messages

Enter JSON array in textarea:
```json
[
  {"role": "user", "content": "Your message here"}
]
```
```

**Commit**: `[Module7] Add demo usage documentation`

### Checkpoint 9: Manual Testing
**Goal**: Verify all functionality works

**Test Cases**:
1. ✅ Scenario buttons work with FakeClient
2. ✅ Extraction process shows for each scenario
3. ✅ Custom messages work without API key (FakeClient fallback)
4. ✅ Real API toggle works (if API key available)
5. ✅ Invalid JSON shows error message
6. ✅ Browser console has no errors

**Commit**: (none - just verification)

### Checkpoint 10: Blind Spot Analysis
**Goal**: Document what was learned

**Create**: Update this file with resolution status

**Commit**: `[Module7] Complete blind spots analysis`

---

## Expected Commits (Modular)

1. `[Module7] Add extraction process details to API response`
2. `[Module7] Modify LeadQualifier to return extraction details`
3. `[Module7] Add USE_REAL_API environment variable toggle`
4. `[Module7] Add extraction process transparency section to dashboard`
5. `[Module7] Add custom message input functionality`
6. `[Module7] Support custom messages in request body`
7. `[Module7] Add demo usage documentation`
8. `[Module7] Complete blind spots analysis`

**Total**: 8 commits (modular, each with specific purpose)

---

## Environment Variable Configuration

### .env File Structure

```bash
# Demo Configuration
USE_REAL_API=false  # Set to 'true' to use real Anthropic API

# Anthropic API (required if USE_REAL_API=true)
ANTHROPIC_API_KEY=sk-ant-api03-...  # Your API key here
```

### Docker Compose Integration

```yaml
# docker-compose.yml
services:
  app:
    environment:
      - USE_REAL_API=${USE_REAL_API:-false}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
    env_file:
      - .env
```

### Behavior Matrix

| USE_REAL_API | ANTHROPIC_API_KEY | X-Scenario | Messages in Body | Result |
|--------------|-------------------|------------|------------------|--------|
| false        | (any)             | present    | (any)            | FakeClient scenario |
| false        | (any)             | absent     | present          | FakeClient fallback |
| true         | present           | present    | absent           | FakeClient scenario (override) |
| true         | present           | absent     | present          | Real Anthropic API |
| true         | absent            | (any)      | (any)            | Error: API key required |

---

## Success Criteria

**Original** (from 07-minimal-interface.md):
- [x] Dashboard loads at root path
- [x] 3 scenario buttons work
- [x] Results display lead profile correctly
- [x] Discrepancies highlighted when present
- [x] Property matches shown with scores
- [x] JSON view shows raw response
- [x] No JavaScript errors in console

**Added** (Opción B):
- [x] Extraction process visible (messages, LLM, heuristic, cross-validation)
- [x] Custom message input works
- [x] Real API toggle functional (with USE_REAL_API env var)
- [x] Transparency shows anti-injection methodology
- [x] Demo demonstrates core value proposition

---

**Status**: ✅ COMPLETE - All Opción B checkpoints implemented and verified
**Implementation Summary**:
- Dashboard shows extraction process transparency (4 collapsible sections)
- Custom message input with JSON validation
- USE_REAL_API toggle via checkbox (sets X-Use-Real-API header)
- All tests passing (167 examples, 0 failures)
- Dashboard verified at http://localhost:3001
- Documentation complete (docs/DEMO-USAGE.md)

**Commits**:
1. `[Module7] Reorganize plan-adjustments and update governance docs`
2. `[Module7] Add extraction transparency and custom message input`
3. `[Module7] Update LeadQualifier specs for new return format`
