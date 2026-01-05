require "net/http"
require "json"

module LLM
  # Client for Anthropic Claude API integration
  #
  # Handles lead qualification by extracting structured profile data from conversation messages
  # using Claude Sonnet 4.5 model.
  #
  # Error Handling:
  # - Missing API key: Raises on initialization with clear error message
  # - API errors (500, 503): Logs error message and re-raises StandardError
  # - Rate limiting (429): Logs error and re-raises with API response
  # - Timeout (>30s): Raises Net::OpenTimeout or Net::ReadTimeout
  # - Malformed JSON: Returns empty hash {}
  # - Missing content: Returns empty hash {}
  #
  # Example usage:
  #   client = LLM::AnthropicClient.new
  #   profile = client.extract_profile(messages)
  #   # => { budget: 3_000_000, city: "CDMX", confidence: "high" }
  #
  class AnthropicClient
    CLAUDE_API_URL = "https://api.anthropic.com/v1/messages"
    # Updated to Claude Sonnet 4.5 (Claude 3.5 Sonnet retired December 2025)
    # Can be overridden via CLAUDE_MODEL environment variable
    CLAUDE_MODEL = ENV.fetch("CLAUDE_MODEL", "claude-sonnet-4-5")

    def initialize
      @api_key = ENV["ANTHROPIC_API_KEY"]
      raise "ANTHROPIC_API_KEY environment variable not set" unless @api_key
    end

    # Extracts structured profile data from conversation messages
    #
    # @param messages [Array<Hash>] Array of message hashes with :role and :content
    # @return [Hash] Extracted profile with symbolized keys (budget, city, area, etc.)
    # @raise [StandardError] If API request fails
    # @raise [Net::OpenTimeout, Net::ReadTimeout] If request times out
    def extract_profile(messages)
      response = call_api(build_request(messages))
      parse_response(response)
    rescue StandardError => e
      Rails.logger.error("Anthropic API error: #{e.message}")
      raise
    end

    private

    def build_request(messages)
      {
        model: CLAUDE_MODEL,
        max_tokens: 1024,
        system: system_prompt,
        messages: messages.map { |m| { role: m[:role], content: m[:content] } }
      }
    end

    def system_prompt
      <<~PROMPT
        You are a lead qualification assistant for a real estate platform.
        Extract the following information from the conversation:
        - budget (numeric, in MXN)
        - city (string)
        - area (string, neighborhood name)
        - bedrooms (integer)
        - bathrooms (integer)
        - property_type (casa, departamento, terreno)
        - phone (string, if provided)

        Return ONLY a JSON object with these fields. Omit fields if not mentioned.
        Be precise with numbers and do not confuse phone numbers with budgets.

        Example output:
        {
          "budget": 3000000,
          "city": "CDMX",
          "area": "Roma Norte",
          "bedrooms": 2,
          "confidence": "high"
        }
      PROMPT
    end

    def call_api(request_body)
      uri = URI(CLAUDE_API_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri.path)
      request["Content-Type"] = "application/json"
      request["x-api-key"] = @api_key
      request["anthropic-version"] = "2023-06-01"
      request.body = request_body.to_json

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise "API request failed: #{response.code} - #{response.body}"
      end

      JSON.parse(response.body)
    end

    def parse_response(api_response)
      content = api_response.dig("content", 0, "text")
      return {} unless content

      # Extract JSON from response (Claude might wrap it in markdown)
      json_match = content.match(/\{.*\}/m)
      return {} unless json_match

      parsed = JSON.parse(json_match[0])

      # Normalize keys to symbols and ensure types
      {
        budget: parsed["budget"]&.to_i,
        city: parsed["city"],
        area: parsed["area"],
        bedrooms: parsed["bedrooms"]&.to_i,
        bathrooms: parsed["bathrooms"]&.to_i,
        property_type: parsed["property_type"],
        phone: parsed["phone"],
        confidence: parsed["confidence"] || "medium"
      }.compact
    end
  end
end
