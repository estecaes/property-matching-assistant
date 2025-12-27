module LLM
  class FakeClient
    SCENARIOS = {
      "budget_seeker" => {
        # Happy path: clear budget, city, preferences
        messages: [
          { role: "user", content: "Busco un departamento en CDMX" },
          { role: "assistant", content: "¿En qué zona te gustaría?" },
          { role: "user", content: "Roma Norte, 2 recámaras" },
          { role: "assistant", content: "¿Cuál es tu presupuesto?" },
          { role: "user", content: "Hasta 3 millones" }
        ],
        llm_response: {
          budget: 3_000_000,
          city: "CDMX",
          area: "Roma Norte",
          bedrooms: 2,
          confidence: "high"
        },
        heuristic_response: {
          budget: 3_000_000,
          city: "CDMX",
          area: "Roma Norte",
          bedrooms: 2,
          property_type: "departamento"
        }
      },
      "budget_mismatch" => {
        # Anti-injection: LLM extracts different budget than heuristic
        messages: [
          { role: "user", content: "Busco depa en Guadalajara" },
          { role: "assistant", content: "¿Cuál es tu presupuesto?" },
          { role: "user", content: "Mi presupuesto es 5 millones pero realmente solo tengo 3" }
        ],
        llm_response: {
          budget: 5_000_000,  # LLM picks first number
          city: "Guadalajara",
          property_type: "departamento",
          confidence: "medium"
        },
        heuristic_response: {
          budget: 3_000_000,  # Heuristic picks last number
          city: "Guadalajara",
          property_type: "departamento"
        }
      },
      "phone_vs_budget" => {
        # Edge case: distinguish phone number from budget
        messages: [
          { role: "user", content: "Busco casa en Monterrey" },
          { role: "assistant", content: "Cuéntame más sobre lo que buscas" },
          { role: "user", content: "presupuesto 3 millones, mi tel es 5512345678" }
        ],
        llm_response: {
          budget: 3_000_000,
          city: "Monterrey",
          phone: "5512345678",
          property_type: "casa",
          confidence: "high"
        },
        heuristic_response: {
          budget: 3_000_000,  # NOT 5512345678
          city: "Monterrey",
          property_type: "casa"
        }
      }
    }.freeze

    def extract_profile(messages)
      # Check if USE_REAL_API is enabled
      if self.class.should_use_real_api?
        Rails.logger.info("USE_REAL_API=true, using AnthropicClient")
        return LLM::AnthropicClient.new.extract_profile(messages)
      end

      scenario_data = SCENARIOS[Current.scenario]
      return scenario_data[:llm_response] if scenario_data

      # Fallback: If API key is present (e.g., VCR tests), use AnthropicClient
      if ENV['ANTHROPIC_API_KEY'].present?
        Rails.logger.info("No scenario match, falling back to AnthropicClient")
        return LLM::AnthropicClient.new.extract_profile(messages)
      end

      # Otherwise simulate LLM extraction for custom messages without API key
      Rails.logger.info("No scenario match, simulating LLM extraction for custom messages")
      simulate_llm_extraction(messages)
    end

    def self.should_use_real_api?
      ENV['USE_REAL_API'] == 'true' && ENV['ANTHROPIC_API_KEY'].present?
    end

    private

    # Simulates LLM extraction for custom messages without API key
    # Strategy: Extract values using keyword matching but with "LLM-like" behavior:
    # - Picks FIRST mentioned number for budget (vs heuristic which picks last)
    # - More flexible with synonyms
    # - Adds confidence scoring
    def simulate_llm_extraction(messages)
      combined_text = messages.map { |m| m[:content] || m['content'] }.join(" ")

      result = {}

      # Extract budget - LLM picks FIRST number mentioned (can be influenced by prompt injection)
      # Use greedy matching to find first budget mention
      budget_matches = combined_text.scan(/(?:presupuesto|budget).*?(\d+)\s*(?:millones?|millions?|m\b)/i)
      if budget_matches.any?
        # LLM picks FIRST mentioned budget (5 in "presupuesto es 5 millones pero realmente 3m")
        result[:budget] = budget_matches.first[0].to_i * 1_000_000
      elsif combined_text =~ /(\d{7,})/  # 7+ digits (like 3000000)
        result[:budget] = $1.to_i
      end

      # Extract city - flexible matching
      cities = %w[CDMX Guadalajara Monterrey Puebla Querétaro]
      cities.each do |city|
        if combined_text =~ /#{city}/i
          result[:city] = city
          break
        end
      end

      # Extract property type - flexible synonyms
      if combined_text =~ /\b(depa|departamento|apartment)\b/i
        result[:property_type] = "departamento"
      elsif combined_text =~ /\b(casa|house)\b/i
        result[:property_type] = "casa"
      elsif combined_text =~ /\b(terreno|land)\b/i
        result[:property_type] = "terreno"
      end

      # Extract bedrooms
      if combined_text =~ /(\d+)\s*(?:recámaras?|bedrooms?|habitaciones?)/i
        result[:bedrooms] = $1.to_i
      end

      # Extract phone - LLM might extract phone numbers
      if combined_text =~ /(?:tel|teléfono|phone|cel|celular)[\s:]*(\d{10})/i
        result[:phone] = $1
      end

      # Add confidence based on how much data was extracted
      result[:confidence] = if result.keys.size >= 3
                              "high"
                            elsif result.keys.size >= 2
                              "medium"
                            else
                              "low"
                            end

      result
    end

    def self.scenario_messages(scenario_name)
      # If USE_REAL_API is true, return empty to allow custom messages
      return [] if should_use_real_api?

      SCENARIOS.dig(scenario_name, :messages) || []
    end

    def self.heuristic_response(scenario_name)
      SCENARIOS.dig(scenario_name, :heuristic_response) || {}
    end
  end
end
