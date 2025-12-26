# frozen_string_literal: true

# LeadQualifier: Anti-injection lead qualification service
#
# This service implements dual extraction (LLM + heuristic) with cross-validation
# to detect potential prompt injection attempts and ensure data reliability.
#
# Architecture:
# 1. LLM Extraction: Context-aware, flexible, handles natural language
# 2. Heuristic Extraction: Defensive regex-based, predictable, injection-resistant
# 3. Cross-Validation: Compares both extractions, generates observable discrepancies
# 4. Defensive Merging: Prefers heuristic values when conflict detected
#
# Usage:
#   session = ConversationSession.find(id)
#   LeadQualifier.call(session)
#
class LeadQualifier
  def self.call(session)
    new(session).call
  end

  def initialize(session)
    @session = session
    @start_time = Time.current
  end

  def call
    messages = @session.messages.ordered.map { |m| { role: m.role, content: m.content } }

    # Dual extraction with independent validation
    llm_profile = extract_from_llm(messages)
    heuristic_profile = extract_heuristic(messages)

    # Cross-validation and discrepancy detection
    discrepancies = compare_profiles(llm_profile, heuristic_profile)

    # Defensive merge: prefer heuristic for conflicting fields
    final_profile = merge_profiles(llm_profile, heuristic_profile, discrepancies)

    # Populate session with results
    @session.lead_profile = final_profile
    @session.discrepancies = discrepancies
    @session.needs_human_review = requires_review?(discrepancies)
    @session.qualification_duration_ms = [((Time.current - @start_time) * 1000).to_i, 1].max
    @session.status = "qualified"
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
    {} # Graceful fallback to heuristic-only
  end

  def extract_heuristic(messages)
    # Combine all user messages into one text block
    text = messages.select { |m| m[:role] == "user" }.map { |m| m[:content] }.join(" ")

    profile = {}
    profile[:budget] = extract_budget(text)
    profile[:city] = extract_city(text)
    profile[:area] = extract_area(text)
    profile[:bedrooms] = extract_bedrooms(text)
    profile[:bathrooms] = extract_bathrooms(text)
    profile[:property_type] = extract_property_type(text)

    Rails.logger.info("Heuristic extraction: #{profile.inspect}")
    profile.compact
  end

  # Budget extraction with phone number distinction
  # Strategy: Find ALL budget mentions, use LAST valid one (defensive against manipulation)
  def extract_budget(text)
    budget_patterns = [
      /(?:presupuesto|budget|hasta|máximo|tengo|solo)\s*(?:de|es|:)?\s*(\d+)\s*(?:millones|millón|m(?:illones)?)/i,
      /(?:presupuesto|budget|hasta|máximo|tengo|solo)\s*(?:de|es|:)?\s*\$?\s*(\d{1,2}[,.]?\d{3}[,.]?\d{3})/i,
      /(?:tengo|solo)\s*(?:de|es|:)?\s*(\d+)(?!\d)/i  # "tengo 3" without "millones"
    ]

    last_valid_budget = nil

    budget_patterns.each do |pattern|
      # Find ALL matches, not just first
      text.scan(pattern).each do |matches|
        number = matches[0].gsub(/[,.]/, "").to_i

        # Validation: reasonable budget range (500K - 50M MXN)
        # Excludes phone numbers (10 digits without context)
        if number.between?(1, 100) # Written as millions or bare numbers interpreted as millions
          last_valid_budget = number * 1_000_000
        elsif number.between?(500_000, 50_000_000)
          last_valid_budget = number
        end
      end
    end

    last_valid_budget
  end

  def extract_city(text)
    cities = ["CDMX", "Ciudad de México", "Guadalajara", "Monterrey", "Querétaro", "Puebla"]

    cities.each do |city|
      return "CDMX" if text.match?(/\b#{Regexp.escape(city)}\b/i) && city.match?(/CDMX|Ciudad de México/)
      return city if text.match?(/\b#{Regexp.escape(city)}\b/i)
    end

    nil
  end

  def extract_area(text)
    # Common CDMX areas
    areas = [
      "Roma Norte", "Roma Sur", "Condesa", "Polanco", "Del Valle",
      "Coyoacán", "Santa Fe", "Narvarte", "Juárez", "Doctores",
      "San Pedro" # For Monterrey tests
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
    return "departamento" if text.match?(/\b(?:depa|departamento|apartment)\b/i)
    return "casa" if text.match?(/\b(?:casa|house)\b/i)
    return "terreno" if text.match?(/\b(?:terreno|land|lote)\b/i)

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
        severity: diff_pct > 30 ? "high" : "medium"
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
        severity: "medium"
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
      d[:severity] == "high" || (d[:diff_pct] && d[:diff_pct] > 20)
    end
  end

  def log_qualification_result
    Rails.logger.info({
      event: "lead_qualified",
      session_id: @session.id,
      profile: @session.lead_profile,
      discrepancies_count: @session.discrepancies.size,
      needs_review: @session.needs_human_review,
      duration_ms: @session.qualification_duration_ms
    }.to_json)
  end
end
