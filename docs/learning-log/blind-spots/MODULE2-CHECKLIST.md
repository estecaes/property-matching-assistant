# Module 2: Post-Implementation Checklist

**Before proceeding to Module 3**, verify/fix these items:

---

## 🔴 CRITICAL (Must Fix)

- [ ] **Add validation: discrepancies must be Array**
  ```ruby
  # In app/models/conversation_session.rb
  validate :discrepancies_must_be_array

  private

  def discrepancies_must_be_array
    unless discrepancies.is_a?(Array)
      errors.add(:discrepancies, 'must be an Array')
    end
  end
  ```
  - Why: Module 4 will push to this array, must ensure type safety
  - Test: Add spec to verify validation

---

## 🟡 IMPORTANT (Should Fix)

- [ ] **Document JSONB structures in models**
  ```ruby
  # In app/models/conversation_session.rb
  # Add comment above class:
  #
  # lead_profile expected structure:
  #   {
  #     "city" => String,
  #     "budget" => Integer (500_000..50_000_000),
  #     "bedrooms" => Integer (1..5),
  #     "area" => String (optional),
  #     "confidence" => String (optional)
  #   }
  #
  # discrepancies expected structure (Array of):
  #   {
  #     "field" => String,
  #     "llm" => Any,
  #     "heuristic" => Any,
  #     "diff_pct" => Float
  #   }
  ```

- [ ] **Add budget range validation**
  ```ruby
  # In app/models/conversation_session.rb
  validate :budget_within_range, if: -> { lead_profile['budget'].present? }

  private

  def budget_within_range
    budget = lead_profile['budget']
    unless budget.between?(500_000, 100_000_000)
      errors.add(:lead_profile, 'budget must be between 500K and 100M')
    end
  end
  ```

- [ ] **Increase seed count to 30+ properties**
  - Current: 26 properties
  - Requirement: 30+
  - Fix: Add 2 more areas to any city
  - Example: Add "Benito Juárez" and "Miguel Hidalgo" to CDMX

---

## 🟢 OPTIONAL (Nice to Have)

- [ ] **Test migration rollback**
  ```bash
  docker compose run --rm app rails db:rollback STEP=3
  docker compose run --rm app rails db:migrate
  ```

- [ ] **Verify GIN index exists**
  ```ruby
  # In rails console:
  ActiveRecord::Base.connection.indexes(:conversation_sessions)
    .find { |idx| idx.columns == ['lead_profile'] && idx.using == :gin }
  ```

- [ ] **Add test for non-consecutive message sequence_numbers**
  ```ruby
  # In spec/models/message_spec.rb
  it 'orders messages correctly even with gaps in sequence' do
    session = create(:conversation_session)
    msg_0 = create(:message, conversation_session: session, sequence_number: 0)
    msg_5 = create(:message, conversation_session: session, sequence_number: 5)
    msg_2 = create(:message, conversation_session: session, sequence_number: 2)

    expect(session.messages.ordered.pluck(:sequence_number)).to eq([0, 2, 5])
  end
  ```

- [ ] **Document status transitions**
  ```ruby
  # In app/models/conversation_session.rb
  # Add comment:
  #
  # Valid status transitions:
  #   active -> qualified (normal flow)
  #   active -> failed (error during qualification)
  #   (No backwards transitions implemented)
  ```

- [ ] **Add index on messages.role** (if using scopes frequently)
  ```ruby
  # Migration:
  add_index :messages, :role
  ```

---

## ✅ Already Working (No Action Needed)

- ✅ JSONB defaults initialize correctly
- ✅ Property search handles edge cases properly
- ✅ All tests passing (51 examples)
- ✅ Migrations run successfully
- ✅ Seeds load correctly
- ✅ Foreign keys enforce referential integrity

---

## 📝 Recommendations

### Before Module 3:
1. Fix CRITICAL items (discrepancies validation)
2. Add IMPORTANT documentation (JSONB structures)
3. Consider OPTIONAL tests if time permits

### During Module 3:
- Budget validation can be added when implementing LeadQualifier
- Status transitions can be documented as part of qualification flow

### Deferred:
- State machine gem (production concern)
- Auto-sync turns_count (can compute from messages.count)
- Migration rollback testing (unlikely needed in demo)

---

**Estimated Time**:
- CRITICAL: 15 minutes
- IMPORTANT: 30 minutes
- OPTIONAL: 45 minutes
- **Total: 1.5 hours** (if doing all)

**Minimum Viable**: Fix CRITICAL only (~15 min) before Module 3
