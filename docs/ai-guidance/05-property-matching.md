# Módulo 5: Property Matching - AI Guidance

**Estimated Time**: 1 hour
**Status**: ✅ Complete
**Actual Time**: ~45 minutes
**Dependencies**: Module 2 (Models), Module 4 (LeadQualifier)

---

## Objectives

1. Implement PropertyMatcher service with scoring algorithm
2. City-based prefiltro (mandatory requirement)
3. Budget, bedrooms, area scoring
4. Return top 3 matches with reasons
5. Handle missing city gracefully

---

## Implementation

### Service Object

```ruby
# app/services/property_matcher.rb
class PropertyMatcher
  MAX_RESULTS = 3

  def self.call(lead_profile)
    new(lead_profile).call
  end

  def initialize(lead_profile)
    @profile = lead_profile.symbolize_keys
  end

  def call
    # CRITICAL: City is mandatory
    return no_results('missing_city') unless @profile[:city].present?

    properties = Property.active.in_city(@profile[:city])
    scored_properties = score_properties(properties)
    top_matches = scored_properties.take(MAX_RESULTS)

    format_results(top_matches)
  end

  private

  def score_properties(properties)
    properties.map do |property|
      score = calculate_score(property)
      reasons = generate_reasons(property, score)

      {
        property: property,
        score: score[:total],
        reasons: reasons
      }
    end.sort_by { |m| -m[:score] }
  end

  def calculate_score(property)
    score = { total: 0, components: {} }

    # Budget match (40 points max)
    if @profile[:budget]
      budget_score = score_budget(property.price, @profile[:budget])
      score[:components][:budget] = budget_score
      score[:total] += budget_score
    end

    # Bedrooms match (30 points max)
    if @profile[:bedrooms]
      bedrooms_score = score_bedrooms(property.bedrooms, @profile[:bedrooms])
      score[:components][:bedrooms] = bedrooms_score
      score[:total] += bedrooms_score
    end

    # Area match (20 points max)
    if @profile[:area]
      area_score = score_area(property.area, @profile[:area])
      score[:components][:area] = area_score
      score[:total] += area_score
    end

    # Property type (10 points max)
    if @profile[:property_type]
      type_score = score_property_type(property.property_type, @profile[:property_type])
      score[:components][:property_type] = type_score
      score[:total] += type_score
    end

    score
  end

  def score_budget(price, budget)
    return 0 if price.nil? || budget.nil?

    # Perfect match: within 10%
    diff_pct = ((price - budget).abs.to_f / budget * 100)

    if diff_pct <= 10
      40
    elsif diff_pct <= 20
      30
    elsif diff_pct <= 30
      20
    else
      0
    end
  end

  def score_bedrooms(property_beds, requested_beds)
    return 0 if property_beds.nil? || requested_beds.nil?

    if property_beds == requested_beds
      30
    elsif (property_beds - requested_beds).abs == 1
      20
    else
      0
    end
  end

  def score_area(property_area, requested_area)
    return 0 if property_area.nil? || requested_area.nil?

    if property_area.downcase == requested_area.downcase
      20
    elsif property_area.downcase.include?(requested_area.downcase) ||
          requested_area.downcase.include?(property_area.downcase)
      10
    else
      0
    end
  end

  def score_property_type(property_type, requested_type)
    return 0 if property_type.nil? || requested_type.nil?

    property_type.downcase == requested_type.downcase ? 10 : 0
  end

  def generate_reasons(property, score_data)
    reasons = []
    components = score_data[:components]

    reasons << 'budget_exact_match' if components[:budget] == 40
    reasons << 'budget_close_match' if components[:budget]&.between?(20, 39)
    reasons << 'bedrooms_exact_match' if components[:bedrooms] == 30
    reasons << 'bedrooms_close_match' if components[:bedrooms] == 20
    reasons << 'area_exact_match' if components[:area] == 20
    reasons << 'area_partial_match' if components[:area] == 10
    reasons << 'property_type_match' if components[:property_type] == 10

    reasons
  end

  def format_results(scored_matches)
    scored_matches.map do |match|
      {
        id: match[:property].id,
        title: match[:property].title,
        price: match[:property].price.to_f,
        city: match[:property].city,
        area: match[:property].area,
        bedrooms: match[:property].bedrooms,
        bathrooms: match[:property].bathrooms,
        score: match[:score],
        reasons: match[:reasons]
      }
    end
  end

  def no_results(reason)
    Rails.logger.warn("No property matches: #{reason}")
    []
  end
end
```

---

## Scoring Algorithm

### Total Possible: 100 points

| Factor | Weight | Perfect Match | Notes |
|--------|--------|---------------|-------|
| Budget | 40 pts | ±10% of requested | Most important factor |
| Bedrooms | 30 pts | Exact match | ±1 bedroom = 20 pts |
| Area | 20 pts | Exact string match | Partial = 10 pts |
| Property Type | 10 pts | Exact match | casa vs departamento |

### Example Scoring

```ruby
# Lead: budget 3M, CDMX, Roma Norte, 2 bedrooms
# Property: 2.95M, CDMX, Roma Norte, 2 beds, departamento

Budget: 40 points (within 2%)
Bedrooms: 30 points (exact)
Area: 20 points (exact)
Type: 0 points (not specified)
---
TOTAL: 90 points
```

---

## Testing Requirements

```ruby
# spec/services/property_matcher_spec.rb
require 'rails_helper'

RSpec.describe PropertyMatcher do
  describe '.call' do
    let!(:perfect_match) do
      create(:property,
        price: 3_000_000,
        city: 'CDMX',
        area: 'Roma Norte',
        bedrooms: 2
      )
    end

    let!(:close_match) do
      create(:property,
        price: 3_500_000,
        city: 'CDMX',
        area: 'Roma Sur',
        bedrooms: 2
      )
    end

    let!(:wrong_city) do
      create(:property,
        price: 3_000_000,
        city: 'Guadalajara',
        bedrooms: 2
      )
    end

    context 'with city specified' do
      let(:profile) do
        {
          budget: 3_000_000,
          city: 'CDMX',
          area: 'Roma Norte',
          bedrooms: 2
        }
      end

      it 'returns top matches sorted by score' do
        results = described_class.call(profile)

        expect(results.size).to be <= 3
        expect(results.first[:id]).to eq(perfect_match.id)
        expect(results.first[:score]).to be > results.second[:score] if results.second
      end

      it 'includes reasons for matching' do
        results = described_class.call(profile)

        expect(results.first[:reasons]).to include('budget_exact_match')
        expect(results.first[:reasons]).to include('bedrooms_exact_match')
        expect(results.first[:reasons]).to include('area_exact_match')
      end

      it 'excludes properties from other cities' do
        results = described_class.call(profile)

        result_ids = results.map { |r| r[:id] }
        expect(result_ids).not_to include(wrong_city.id)
      end
    end

    context 'without city' do
      let(:profile) { { budget: 3_000_000, bedrooms: 2 } }

      it 'returns empty results' do
        results = described_class.call(profile)
        expect(results).to be_empty
      end
    end

    context 'with no matching properties' do
      let(:profile) do
        {
          budget: 1_000_000,
          city: 'Querétaro',
          bedrooms: 5
        }
      end

      it 'returns empty results' do
        results = described_class.call(profile)
        expect(results).to be_empty
      end
    end
  end
end
```

---

## Critical Constraints

### City Requirement
❌ **WRONG**: Return all properties if city missing
✅ **CORRECT**: Return empty array if city missing

**Reason**: Prevents irrelevant matches from flooding results.

### Top 3 Limit
- Always return maximum 3 properties
- Sorted by score descending
- If <3 properties match, return what's available

### Scoring Transparency
- Include `reasons` array explaining why property matched
- Reasons are machine-readable for frontend display
- Helps users understand match quality

---

## Success Criteria

- [x] Returns top 3 matches sorted by score ✅
- [x] City filter mandatory (returns [] if missing) ✅
- [x] Scoring algorithm weights budget > bedrooms > area ✅
- [x] Reasons array explains match quality ✅
- [x] Tests cover edge cases (no matches, missing city) ✅

**Test Results**: 24 examples, 0 failures
**Full Suite**: 151 examples, 0 failures

---

**Last Updated**: 2025-12-27
**Completed**: 2025-12-27
