# frozen_string_literal: true

# PropertyMatcher: Scoring-based property matching service
#
# Scores properties on a 100-point scale based on:
# - Budget match (40 points max)
# - Bedrooms match (30 points max)
# - Area match (20 points max)
# - Property type match (10 points max)
#
# Returns top 3 matches with transparent scoring reasons.
#
# Usage:
#   profile = { budget: 3_000_000, city: "CDMX", bedrooms: 2 }
#   matches = PropertyMatcher.call(profile)
#
class PropertyMatcher
  MAX_RESULTS = 3

  def self.call(lead_profile)
    new(lead_profile).call
  end

  def initialize(lead_profile)
    @profile = lead_profile.symbolize_keys
  end

  def call
    # CRITICAL: City is mandatory to prevent irrelevant matches
    return no_results("missing_city") unless @profile[:city].present?

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
        score_components: score[:components],
        reasons: reasons
      }
    end.sort_by { |m| -m[:score] } # Descending order
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

    # Calculate percentage difference
    diff_pct = ((price - budget).abs.to_f / budget * 100)

    # Tiered scoring based on budget match quality
    if diff_pct <= 10
      40 # Perfect match: within 10%
    elsif diff_pct <= 20
      30 # Close match: within 20%
    elsif diff_pct <= 30
      20 # Acceptable: within 30%
    else
      0  # Too far from budget
    end
  end

  def score_bedrooms(property_beds, requested_beds)
    return 0 if property_beds.nil? || requested_beds.nil?

    if property_beds == requested_beds
      30 # Exact match
    elsif (property_beds - requested_beds).abs == 1
      20 # Close match: ±1 bedroom
    else
      0  # Too different
    end
  end

  def score_area(property_area, requested_area)
    return 0 if property_area.nil? || requested_area.nil?

    # Case-insensitive comparison
    prop_area_lower = property_area.downcase
    req_area_lower = requested_area.downcase

    if prop_area_lower == req_area_lower
      20 # Exact match
    elsif prop_area_lower.include?(req_area_lower) || req_area_lower.include?(prop_area_lower)
      10 # Partial match (e.g., "Roma" matches "Roma Norte")
    else
      0  # No match
    end
  end

  def score_property_type(property_type, requested_type)
    return 0 if property_type.nil? || requested_type.nil?

    # Case-insensitive exact match
    property_type.downcase == requested_type.downcase ? 10 : 0
  end

  def generate_reasons(property, score_data)
    reasons = []
    components = score_data[:components]

    # Budget reasons
    reasons << "budget_exact_match" if components[:budget] == 40
    reasons << "budget_close_match" if components[:budget]&.between?(20, 39)

    # Bedrooms reasons
    reasons << "bedrooms_exact_match" if components[:bedrooms] == 30
    reasons << "bedrooms_close_match" if components[:bedrooms] == 20

    # Area reasons
    reasons << "area_exact_match" if components[:area] == 20
    reasons << "area_partial_match" if components[:area] == 10

    # Property type reason
    reasons << "property_type_match" if components[:property_type] == 10

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
