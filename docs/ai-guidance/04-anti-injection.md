# Módulo 4: Anti-Injection Core - AI Guidance

**Estimated Time**: 2.5 hours ⭐ **CRÍTICO**
**Status**: ✅ Complete
**Dependencies**: Module 3 (LLM Adapter)

---

## ⚠️ CRITICAL MODULE WARNING

This is the **most important module** in the demo. It demonstrates:
- Senior-level defensive programming
- LLM security awareness
- Observable evidence generation
- Complex edge case handling

Do NOT rush this module. Budget 2.5 hours and test thoroughly.

---

## Objectives

1. Implement LeadQualifier service with dual extraction
2. LLM extraction using FakeClient/AnthropicClient
3. Heuristic extraction using defensive regex
4. Cross-validation and discrepancy detection
5. Handle critical edge cases (phone vs budget)
6. Populate ConversationSession with results

---

## Architecture Overview

```
LeadQualifier.call(session)
    │
    ├──> extract_from_llm(messages)
    │    └──> LLM::FakeClient/AnthropicClient
    │
    ├──> extract_heuristic(messages)
    │    └──> Regex + defensive patterns
    │
    ├──> compare_profiles(llm, heuristic)
    │    └──> Calculate discrepancies[]
    │
    └──> populate_session(session, profiles, discrepancies)
         └──> Update session.lead_profile, session.discrepancies
```

---

## Implementation

### Service Object Structure

```ruby
# app/services/lead_qualifier.rb
class LeadQualifier
  # Main entry point
  def self.call(session)
    new(session).call
  end

  def initialize(session)
    @session = session
    @start_time = Time.current
  end

  def call
    messages = @session.messages.ordered.map { |m| { role: m.role, content: m.content } }

    # Dual extraction
    llm_profile = extract_from_llm(messages)
    heuristic_profile = extract_heuristic(messages)

    # Cross-validation
    discrepancies = compare_profiles(llm_profile, heuristic_profile)

    # Determine final profile (prefer heuristic for conflicting fields)
    final_profile = merge_profiles(llm_profile, heuristic_profile, discrepancies)

    # Populate session
    @session.lead_profile = final_profile
    @session.discrepancies = discrepancies
    @session.needs_human_review = requires_review?(discrepancies)
    @session.qualification_duration_ms = ((Time.current - @start_time) * 1000).to_i
    @session.status = 'qualified'
    @session.save!

    log_qualification_result

    @session
  end

  private

  def extract_from_llm(messages)
    client = LLM::FakeClient.new
    result = client.extract_profile(messages)

    Rails.logger.info("LLM extraction: #{result.inspect}")
    result
  rescue StandardError => e
    Rails.logger.error("LLM extraction failed: #{e.message}")
    {} # Graceful fallback to heuristic only
  end

  def extract_heuristic(messages)
    # Combine all user messages into one text block
    text = messages.select { |m| m[:role] == 'user' }.map { |m| m[:content] }.join(' ')

    profile = {}

    # Budget extraction (CRITICAL: distinguish from phone)
    profile[:budget] = extract_budget(text)

    # City extraction
    profile[:city] = extract_city(text)

    # Area extraction
    profile[:area] = extract_area(text)

    # Bedrooms
    profile[:bedrooms] = extract_bedrooms(text)

    # Bathrooms
    profile[:bathrooms] = extract_bathrooms(text)

    # Property type
    profile[:property_type] = extract_property_type(text)

    Rails.logger.info("Heuristic extraction: #{profile.inspect}")
    profile.compact
  end

  def extract_budget(text)
    # Patterns for budget with context
    budget_patterns = [
      /(?:presupuesto|budget|hasta|máximo|tengo)[\s:]*(\d+)\s*(?:millones|millón|m(?:illones)?)/i,
      /(?:presupuesto|budget|hasta|máximo|tengo)[\s:]*\$?\s*(\d{1,2}[,.]?\d{3}[,.]?\d{3})/i,
      /(\d+)\s*(?:millones|millón|m(?:illones)?)/i
    ]

    budget_patterns.each do |pattern|
      match = text.match(pattern)
      next unless match

      number = match[1].gsub(/[,.]/, '').to_i

      # Validation: budget should be reasonable (500K - 50M MXN)
      # and NOT a phone number (phone numbers are 10 digits without decimals)
      if number.between?(1, 100) # Written as millions
        return number * 1_000_000
      elsif number.between?(500_000, 50_000_000)
        return number
      end
    end

    nil
  end

  def extract_city(text)
    cities = ['CDMX', 'Ciudad de México', 'Guadalajara', 'Monterrey', 'Querétaro', 'Puebla']

    cities.each do |city|
      return 'CDMX' if text.match?(/\b#{Regexp.escape(city)}\b/i) && city.match?(/CDMX|Ciudad de México/)
      return city if text.match?(/\b#{Regexp.escape(city)}\b/i)
    end

    nil
  end

  def extract_area(text)
    # Common CDMX areas
    areas = [
      'Roma Norte', 'Roma Sur', 'Condesa', 'Polanco', 'Del Valle',
      'Coyoacán', 'Santa Fe', 'Narvarte', 'Juárez', 'Doctores'
    ]

    areas.each do |area|
      return area if text.match?(/\b#{Regexp.escape(area)}\b/i)
    end

    nil
  end

  def extract_bedrooms(text)
    patterns = [
      /(\d+)\s*(?:recámaras?|rec|habitaciones?|cuartos?|bedrooms?)/i,
      /(?:recámaras?|rec|habitaciones?|cuartos?|bedrooms?)\s*(\d+)/i
    ]

    patterns.each do |pattern|
      match = text.match(pattern)
      return match[1].to_i if match && match[1].to_i.between?(1, 10)
    end

    nil
  end

  def extract_bathrooms(text)
    patterns = [
      /(\d+)\s*(?:baños?|bath|bathrooms?)/i,
      /(?:baños?|bath|bathrooms?)\s*(\d+)/i
    ]

    patterns.each do |pattern|
      match = text.match(pattern)
      return match[1].to_i if match && match[1].to_i.between?(1, 10)
    end

    nil
  end

  def extract_property_type(text)
    return 'departamento' if text.match?(/\b(?:depa|departamento|apartment)\b/i)
    return 'casa' if text.match?(/\b(?:casa|house)\b/i)
    return 'terreno' if text.match?(/\b(?:terreno|land|lote)\b/i)

    nil
  end

  def compare_profiles(llm, heuristic)
    discrepancies = []

    # Compare numeric fields with percentage difference
    numeric_fields = [:budget, :bedrooms, :bathrooms]

    numeric_fields.each do |field|
      llm_val = llm[field]
      heur_val = heuristic[field]

      next if llm_val.nil? || heur_val.nil?
      next if llm_val == heur_val

      # Calculate percentage difference
      diff_pct = (((llm_val - heur_val).abs.to_f / [llm_val, heur_val].max) * 100).round(1)

      discrepancies << {
        field: field.to_s,
        llm_value: llm_val,
        heuristic_value: heur_val,
        diff_pct: diff_pct,
        severity: diff_pct > 50 ? 'high' : 'medium'
      }
    end

    # Compare string fields (exact match)
    string_fields = [:city, :area, :property_type]

    string_fields.each do |field|
      llm_val = llm[field]
      heur_val = heuristic[field]

      next if llm_val.nil? || heur_val.nil?
      next if llm_val.to_s.downcase == heur_val.to_s.downcase

      discrepancies << {
        field: field.to_s,
        llm_value: llm_val,
        heuristic_value: heur_val,
        severity: 'medium'
      }
    end

    discrepancies
  end

  def merge_profiles(llm, heuristic, discrepancies)
    # Strategy: For conflicting fields, prefer heuristic (defensive)
    # For non-conflicting, merge both

    merged = {}
    conflicting_fields = discrepancies.map { |d| d[:field].to_sym }

    # Add all heuristic values (defensive preference)
    merged.merge!(heuristic)

    # Add LLM values only if not conflicting
    llm.each do |key, value|
      merged[key] = value unless conflicting_fields.include?(key) || merged.key?(key)
    end

    merged
  end

  def requires_review?(discrepancies)
    # Human review if any high severity or >20% difference
    discrepancies.any? do |d|
      d[:severity] == 'high' || (d[:diff_pct] && d[:diff_pct] > 20)
    end
  end

  def log_qualification_result
    Rails.logger.info({
      event: 'lead_qualified',
      session_id: @session.id,
      profile: @session.lead_profile,
      discrepancies_count: @session.discrepancies.size,
      needs_review: @session.needs_human_review,
      duration_ms: @session.qualification_duration_ms
    }.to_json)
  end
end
```

---

## Critical Edge Cases

### 1. Phone vs Budget Extraction

**Input**: "presupuesto 3 millones, mi tel 5512345678"

**Challenge**: Both are numbers, heuristic must distinguish context.

**Solution**:
```ruby
def extract_budget(text)
  # ONLY match numbers with budget keywords nearby
  /(?:presupuesto|budget)[\s:]*(\d+)\s*millones/i

  # Validate: budget 500K-50M, NOT 10-digit phone numbers
  if number.between?(500_000, 50_000_000)
    return number
  end
end
```

### 2. Budget Format Variations

Must handle:
- "3 millones" → 3,000,000
- "3M" → 3,000,000
- "$3,000,000" → 3,000,000
- "tres millones" → (LLM handles, heuristic may miss)

### 3. LLM Manipulation

**Input**: "Mi presupuesto es 5 millones pero realmente solo tengo 3"

**Expected**:
- LLM: extracts 5,000,000 (first number)
- Heuristic: extracts 3,000,000 (last number with context)
- Discrepancy: 66.7% difference
- needs_human_review: true

---

## Testing Requirements

### Unit Tests

```ruby
# spec/services/lead_qualifier_spec.rb
require 'rails_helper'

RSpec.describe LeadQualifier do
  let(:session) { create(:conversation_session) }

  describe 'budget_seeker scenario' do
    before do
      Current.scenario = 'budget_seeker'
      create_messages(session, LLM::FakeClient.scenario_messages('budget_seeker'))
    end

    it 'qualifies lead without discrepancies' do
      result = described_class.call(session)

      expect(result.lead_profile['budget']).to eq(3_000_000)
      expect(result.lead_profile['city']).to eq('CDMX')
      expect(result.discrepancies).to be_empty
      expect(result.needs_human_review).to be false
      expect(result.status).to eq('qualified')
    end
  end

  describe 'budget_mismatch scenario' do
    before do
      Current.scenario = 'budget_mismatch'
      create_messages(session, LLM::FakeClient.scenario_messages('budget_mismatch'))
    end

    it 'detects budget discrepancy' do
      result = described_class.call(session)

      expect(result.discrepancies).not_to be_empty
      budget_disc = result.discrepancies.find { |d| d['field'] == 'budget' }
      expect(budget_disc).to be_present
      expect(budget_disc['diff_pct']).to be > 20
      expect(result.needs_human_review).to be true
    end
  end

  describe 'phone_vs_budget scenario' do
    before do
      Current.scenario = 'phone_vs_budget'
      create_messages(session, LLM::FakeClient.scenario_messages('phone_vs_budget'))
    end

    it 'extracts budget correctly, not phone number' do
      result = described_class.call(session)

      expect(result.lead_profile['budget']).to eq(3_000_000)
      expect(result.lead_profile['budget']).not_to eq(5_512_345_678)
    end
  end

  def create_messages(session, messages)
    messages.each_with_index do |msg, index|
      session.messages.create!(
        role: msg[:role],
        content: msg[:content],
        sequence_number: index
      )
    end
  end
end
```

---

## VCR Integration Tests (CRÍTICO - Blind Spot Discovered)

### Problem

The tests above use ONLY `FakeClient` with hardcoded responses. This validates business logic but does NOT test:
- Real API integration with `AnthropicClient`
- Response format from actual Anthropic API
- Robustness against API format changes

### Solution: Add VCR Tests

```ruby
# spec/services/lead_qualifier_spec.rb (add after existing tests)

context "with real Anthropic API responses (VCR integration)", :vcr do
  before do
    Current.scenario = nil  # Force fallback to AnthropicClient
  end

  it "qualifies lead using phone_vs_budget cassette" do
    # Messages must match cassette request exactly
    session.messages.create!(role: "user", content: "Busco depa en CDMX", sequence_number: 0)
    session.messages.create!(role: "assistant", content: "¿Presupuesto y teléfono?", sequence_number: 1)
    session.messages.create!(role: "user", content: "Presupuesto 2 millones, mi cel es 5512345678", sequence_number: 2)

    VCR.use_cassette("anthropic/phone_vs_budget") do
      result = described_class.call(session)

      # Verify with REAL API response
      expect(result.lead_profile["budget"]).to eq(2_000_000)
      expect(result.lead_profile["phone"]).to eq("5512345678")
      expect(result.lead_profile["city"]).to eq("CDMX")
      expect(result.lead_profile["property_type"]).to eq("departamento")
      expect(result.status).to eq("qualified")
    end
  end

  it "qualifies lead using extract_simple_profile cassette (happy path)" do
    session.messages.create!(role: "user", content: "Busco un departamento en CDMX", sequence_number: 0)
    session.messages.create!(role: "assistant", content: "¿Cuál es tu presupuesto?", sequence_number: 1)
    session.messages.create!(role: "user", content: "Tengo hasta 3 millones de pesos", sequence_number: 2)

    VCR.use_cassette("anthropic/extract_simple_profile") do
      result = described_class.call(session)

      expect(result.lead_profile["budget"]).to eq(3_000_000)
      expect(result.lead_profile["city"]).to eq("CDMX")
      expect(result.lead_profile["property_type"]).to eq("departamento")
      expect(result.discrepancies).to be_empty
    end
  end

  it "handles markdown-wrapped JSON from API" do
    # Uses cassette with JSON wrapped in ```json...```
    session.messages.create!(role: "user", content: "Busco depa", sequence_number: 0)

    VCR.use_cassette("anthropic/markdown_wrapped_json") do
      result = described_class.call(session)

      # Should parse successfully despite markdown wrapper
      expect(result.lead_profile).not_to be_empty
      expect(result.status).to eq("qualified")
    end
  end
end
```

### Why This Matters

**FakeClient tests**: Fast, reliable, test business logic (10 examples)
**VCR tests**: Slow, validate real integration, catch format changes (3-4 examples)

Both are necessary for production confidence.

### Available VCR Cassettes

- `phone_vs_budget.yml` - Edge case: phone vs budget distinction
- `extract_simple_profile.yml` - Happy path: basic profile extraction
- `extract_complex_profile.yml` - Multiple fields extraction
- `markdown_wrapped_json.yml` - Robust parsing test

---

## Success Criteria

### Core Implementation ✅

- [x] All 3 scenarios pass tests
- [x] Phone vs budget edge case handled correctly
- [x] discrepancies[] populated correctly
- [x] needs_human_review logic works
- [x] Graceful LLM failure fallback
- [x] Structured logging outputs JSON
- [x] qualification_duration_ms recorded

### VCR Integration ⏸️ (CRÍTICO)

- [ ] Test with `phone_vs_budget.yml` cassette
- [ ] Test with `extract_simple_profile.yml` cassette
- [ ] Test with `markdown_wrapped_json.yml` cassette
- [ ] Verify real API response format compatibility

**Status**: Core complete, VCR integration pending
**Discovery**: Blind spot found during Module 4 review (2025-12-26)

---

**Last Updated**: 2025-12-26
