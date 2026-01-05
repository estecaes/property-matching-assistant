class RunsController < ApplicationController
  before_action :set_use_real_api, only: [ :create ]

  def create
    session = create_session_with_messages
    qualification_result = qualify_lead(session)
    matches = match_properties(qualification_result[:session])

    render json: format_response(qualification_result, matches), status: :ok
  rescue StandardError => e
    handle_error(e)
  end

  private

  def set_use_real_api
    if request.headers["X-Use-Real-API"] == "true"
      ENV["USE_REAL_API"] = "true"
    else
      ENV["USE_REAL_API"] = "false"
    end
  end

  def create_session_with_messages
    session = ConversationSession.create!

    messages = if params[:messages].present?
                 # Custom messages from request body
                 params[:messages]
    elsif Current.scenario
                 # FakeClient scenario
                 LLM::FakeClient.scenario_messages(Current.scenario)
    else
                 # No messages
                 []
    end

    messages.each_with_index do |msg, index|
      session.messages.create!(
        role: msg[:role] || msg["role"],
        content: msg[:content] || msg["content"],
        sequence_number: index
      )
    end

    session.update!(turns_count: messages.size)
    session
  end

  def qualify_lead(session)
    LeadQualifier.call(session)
  end

  def match_properties(session)
    return [] unless session.city_present?

    PropertyMatcher.call(session.lead_profile)
  end

  def format_response(qualification_result, matches)
    session = qualification_result[:session]
    extraction_process = qualification_result[:extraction_process]

    {
      session_id: session.id,
      lead_profile: session.lead_profile,
      matches: matches,
      needs_human_review: session.needs_human_review,
      discrepancies: session.discrepancies,
      metrics: {
        qualification_duration_ms: session.qualification_duration_ms,
        turns_count: session.turns_count
      },
      status: session.status,
      extraction_process: extraction_process
    }
  end

  def handle_error(error)
    Rails.logger.error({
      event: "run_error",
      error_class: error.class.name,
      error_message: error.message,
      backtrace: error.backtrace.first(5)
    }.to_json)

    render json: {
      error: "Internal server error",
      message: error.message
    }, status: :internal_server_error
  end
end
