class RunsController < ApplicationController
  def create
    session = create_session_with_messages
    qualify_lead(session)
    matches = match_properties(session)

    render json: format_response(session, matches), status: :ok
  rescue StandardError => e
    handle_error(e)
  end

  private

  def create_session_with_messages
    session = ConversationSession.create!

    messages = if Current.scenario
                 LLM::FakeClient.scenario_messages(Current.scenario)
               else
                 # In production, messages would come from request body
                 []
               end

    messages.each_with_index do |msg, index|
      session.messages.create!(
        role: msg[:role],
        content: msg[:content],
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

  def format_response(session, matches)
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
      status: session.status
    }
  end

  def handle_error(error)
    Rails.logger.error({
      event: 'run_error',
      error_class: error.class.name,
      error_message: error.message,
      backtrace: error.backtrace.first(5)
    }.to_json)

    render json: {
      error: 'Internal server error',
      message: error.message
    }, status: :internal_server_error
  end
end
