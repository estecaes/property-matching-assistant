# frozen_string_literal: true

require "vcr"

VCR.configure do |config|
  # Directory where cassettes (recorded HTTP interactions) are stored
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"

  # Use WebMock to intercept HTTP requests
  config.hook_into :webmock

  # SECURITY: Filter sensitive data from cassettes
  # This prevents API keys from being saved in cassette files
  config.filter_sensitive_data("<ANTHROPIC_API_KEY>") { ENV["ANTHROPIC_API_KEY"] }

  # Filter API key from request headers
  config.filter_sensitive_data("<X-API-KEY-HEADER>") do |interaction|
    interaction.request.headers["X-Api-Key"]&.first
  end

  # Configure matching to ignore certain request differences
  config.default_cassette_options = {
    match_requests_on: [ :method, :uri, :body ],
    record: :once, # Record cassette once, then replay
    allow_playback_repeats: true
  }

  # Allow real HTTP connections when cassette doesn't exist (for recording)
  # This will be disabled in CI to ensure all tests use cassettes
  config.allow_http_connections_when_no_cassette = false unless ENV["CI"]
end
