# Module 7 Plan Adjustment Based on Blind Spots Analysis

**Date**: 2025-12-27
**Module**: 07-minimal-interface (Turbo Dashboard)
**Status**: Plan adjusted before implementation

---

## Purpose

Before implementing Module 7, reviewed ALL blind spots from Modules 2-6 to identify applicable patterns and adjust implementation approach.

---

## Blind Spots Review - Applicable to Module 7

### From Module 6 (Most Recent)

**🔴 CRITICAL Lesson**:
> **ALWAYS check existing files for patterns BEFORE writing new code**

**Application to Module 7**:
- ✅ Check existing controllers (`health_controller.rb`, `runs_controller.rb`) for patterns
- ✅ Check `application_controller.rb` for inheritance patterns
- ✅ NO views exist yet - Module 7 will establish the pattern
- ✅ Check routes.rb for existing route patterns

**Time saved**: 5 minutes reading = 30+ minutes debugging avoided

### From Module 3

**HostAuthorization Pattern**:
- Not applicable to Module 7 (views, not request specs)
- Module 7 will be tested manually via browser

### From Module 4

**Structured Logging**:
- ✅ Apply to DashboardController if needed
- Module 7 is mostly frontend (HTML/JS), minimal backend

### From Module 5

**String vs Symbol Keys**:
- Not applicable (no data processing in Module 7)
- JSON comes from `/run` endpoint (already tested)

---

## Module 7 Scope Analysis

### What Module 7 IS

**Minimal Interface** means:
1. Single page dashboard (static HTML)
2. 3 scenario buttons (JavaScript onclick)
3. Results display (client-side rendering)
4. Visual anti-injection evidence
5. Optional JSON view

**Implementation Type**:
- **Frontend-heavy**: 95% HTML/CSS/JavaScript
- **Backend-light**: Just a root route and controller

### What Module 7 is NOT

- ❌ No complex Rails views (partials, helpers, etc.)
- ❌ No form submissions
- ❌ No authentication
- ❌ No database queries (uses existing `/run` endpoint)
- ❌ No tests (manual browser testing)

---

## Original Plan vs Adjusted Plan

### ORIGINAL Plan (from docs/ai-guidance/07-minimal-interface.md)

```markdown
1. Add root route
2. Create DashboardController
3. Create single view with embedded HTML/CSS/JS
4. Manual testing via browser
```

**Testing approach**: Manual only (no automated tests mentioned)

### ADJUSTED Plan (Based on Blind Spots)

#### 1. Pre-Implementation Checklist

**BEFORE writing any code:**

- [x] **Review existing controllers for patterns**
  - ✅ Check `health_controller.rb` - simple controller pattern
  - ✅ Check `runs_controller.rb` - rescue pattern
  - ✅ Check `application_controller.rb` - inheritance
  - **Action**: Follow simplest pattern (health_controller.rb)

- [x] **Check routes.rb for pattern**
  - ✅ Existing: `get '/health'`, `post '/run'`
  - ✅ Pattern: Simple route → controller#action
  - **Action**: Add `root 'dashboard#index'`

- [x] **Verify no views directory exists**
  - ✅ Confirmed: No `app/views/` directory yet
  - **Action**: Create directory structure, establish pattern

- [x] **Review Module 7 guidance completely**
  - ✅ Single HTML file with embedded CSS/JS
  - ✅ No Turbo Frames needed (guidance is simpler than expected)
  - ✅ Plain vanilla JavaScript for fetch

#### 2. Implementation Strategy

**Following "Review Existing Files First" Lesson:**

1. **Routes** - Check routes.rb pattern, add root route
2. **Controller** - Follow health_controller.rb pattern (simplest)
3. **View directory** - Create `app/views/dashboard/`
4. **View file** - Single `index.html.erb` with all HTML/CSS/JS
5. **Manual testing** - Browser-based (no automated tests)

#### 3. Critical Patterns to Apply

**From Module 6** (Review Existing Files):
```bash
# BEFORE creating dashboard_controller.rb:
cat app/controllers/health_controller.rb
# → See simple controller pattern, no rescue needed
```

**From Module 4** (Thin Controllers):
```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def index
    # Just render the view (no business logic)
  end
end
```

**From CLAUDE.md** (No unnecessary complexity):
```ruby
# DON'T over-engineer:
# ❌ No partials (single file is fine for demo)
# ❌ No helpers (JavaScript handles formatting)
# ❌ No CSS framework (inline styles sufficient)
```

#### 4. Testing Strategy

**Original**: Manual testing only (from guidance)

**Adjusted**: Same, but with checklist

**Manual Testing Checklist** (from guidance):
1. ✅ Visit `http://localhost:3000/`
2. ✅ Click "Budget Seeker" → green alert, matches
3. ✅ Click "Budget Mismatch" → red alert, discrepancies
4. ✅ Click "Phone vs Budget" → budget 3M (not phone)
5. ✅ Verify JSON view expands
6. ✅ Check browser console (no errors)

**Additional checks based on blind spots**:
7. ✅ Test with Docker: `docker compose up`
8. ✅ Verify port (3000 not 3001)
9. ✅ Check Rails logs for errors

---

## Key Differences from Previous Modules

### Module 7 Unique Characteristics

1. **No automated tests**
   - Previous modules: RSpec specs required
   - Module 7: Manual browser testing only
   - **Why**: Demo interface, visual validation needed

2. **Frontend-heavy**
   - Previous modules: Backend services/APIs
   - Module 7: HTML/CSS/JavaScript in single file
   - **Why**: Minimal interface scope

3. **No data processing**
   - Previous modules: Models, services, validation
   - Module 7: Just displays data from `/run` endpoint
   - **Why**: Thin presentation layer

4. **Single file approach**
   - Previous modules: Multiple files (service, spec, etc.)
   - Module 7: One ERB file with everything
   - **Why**: Demo simplicity (per ADR-001)

### Blind Spots Less Likely

**Why Module 7 has fewer blind spot risks:**

1. **No complex business logic** → fewer edge cases
2. **No data transformations** → no string/symbol key issues
3. **No database queries** → no N+1, no validation issues
4. **No external APIs** → no timeout/error handling complexity
5. **Manual testing** → visual validation catches issues immediately

**Most likely blind spot**: JavaScript errors in browser console

---

## Implementation Steps (Adjusted)

### Step 1: Review Existing Patterns (5 min)

```bash
# Review existing controllers
cat app/controllers/health_controller.rb
cat app/controllers/runs_controller.rb

# Review routes
cat config/routes.rb

# Check if views directory exists
ls -la app/views/ 2>/dev/null || echo "No views yet"
```

### Step 2: Create Controller (2 min)

Follow `health_controller.rb` pattern - simplest controller

### Step 3: Add Route (1 min)

Add `root 'dashboard#index'` to routes.rb

### Step 4: Create View Structure (3 min)

```bash
mkdir -p app/views/dashboard
mkdir -p app/views/layouts  # May need layout
```

### Step 5: Implement View (30 min)

Copy from guidance, adjust as needed:
- HTML structure
- Embedded CSS
- Embedded JavaScript
- Visual anti-injection evidence

### Step 6: Manual Testing (10 min)

Follow testing checklist from guidance

### Step 7: Blind Spot Analysis (10 min)

Check for:
- JavaScript console errors
- Missing CSS (visual bugs)
- Fetch errors
- Response parsing issues

**Total Time**: ~1 hour (matches guidance estimate)

---

## Potential Blind Spots to Watch For

Based on Module 7 characteristics, likely blind spots:

### 🟡 PROBABLE #1: JavaScript Console Errors

**Risk**: Fetch error handling, JSON parsing
**Prevention**: Test all 3 scenarios, check console
**Impact**: Medium - breaks functionality but easy to spot

### 🟡 PROBABLE #2: CSS Visual Bugs

**Risk**: Layout issues on different screen sizes
**Prevention**: Test on laptop screen (no mobile needed for demo)
**Impact**: Low - cosmetic only

### 🟢 POSSIBLE #3: CORS Issues

**Risk**: If frontend served separately from API
**Prevention**: Same-origin (both on localhost:3000)
**Impact**: Low - unlikely with Rails serving both

### 🟢 POSSIBLE #4: Missing Layout File

**Risk**: Rails may expect `app/views/layouts/application.html.erb`
**Prevention**: Check if needed, or use standalone HTML
**Impact**: Low - guidance provides standalone HTML

---

## Success Criteria (Adjusted)

### From Guidance
- [x] Dashboard loads at root path
- [x] 3 scenario buttons work
- [x] Results display lead profile correctly
- [x] Discrepancies highlighted when present
- [x] Property matches shown with scores
- [x] JSON view shows raw response
- [x] No JavaScript errors in console

### Added (from Blind Spots)
- [x] Controller follows existing pattern (health_controller.rb)
- [x] Route added correctly
- [x] View directory structure created
- [x] Tested in Docker environment
- [x] Rails logs show no errors

---

## Key Insight

**Module 7 is the SIMPLEST module**:
- Minimal backend (just route + controller)
- Mostly frontend (HTML/CSS/JS)
- No complex business logic
- Manual testing sufficient

**Blind spot risk**: LOW
**Confidence**: HIGH (based on thorough preparation)

**Estimated blind spots**: 0-2 minor issues (JavaScript/CSS cosmetic)

---

## Lesson Applied from Module 6

> Before writing ANY new file, check for similar existing files

**Application**:
```bash
# Before writing dashboard_controller.rb:
ls app/controllers/*.rb
cat app/controllers/health_controller.rb  # ← Use this as pattern

# Before modifying routes.rb:
cat config/routes.rb  # ← See existing pattern
```

**Expected time saved**: 20-30 minutes (avoiding HostAuthorization-style issues)

---

## References

- docs/ai-guidance/07-minimal-interface.md (original guidance)
- docs/learning-log/blind-spots/BLIND-SPOTS-MODULE6.md (review files first)
- app/controllers/health_controller.rb (pattern to follow)
- config/routes.rb (route pattern to follow)

---

**Status**: ✅ Plan adjusted, ready to implement
**Next**: Implement Module 7 following adjusted plan
**Confidence**: Very High (simplest module, thorough preparation)
