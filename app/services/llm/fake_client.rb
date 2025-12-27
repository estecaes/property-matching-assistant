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

      # Fallback to real API if no scenario or unknown scenario
      Rails.logger.info("No scenario match, falling back to AnthropicClient")
      LLM::AnthropicClient.new.extract_profile(messages)
    end

    def self.should_use_real_api?
      ENV['USE_REAL_API'] == 'true' && ENV['ANTHROPIC_API_KEY'].present?
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
