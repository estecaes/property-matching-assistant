class ApplicationController < ActionController::API
  before_action :set_scenario_from_header

  private

  def set_scenario_from_header
    Current.scenario = request.headers["X-Scenario"]
    Rails.logger.info("Scenario set: #{Current.scenario}") if Current.scenario
  end
end
