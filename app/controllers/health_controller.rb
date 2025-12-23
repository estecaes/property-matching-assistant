class HealthController < ApplicationController
  def show
    db_status = database_status

    response_data = {
      status: db_status[:status],
      timestamp: Time.current.iso8601,
      database: db_status[:database],
      version: Rails.version
    }

    if db_status[:database] == "disconnected"
      render json: response_data, status: :internal_server_error
    else
      render json: response_data
    end
  end

  private

  def database_status
    ActiveRecord::Base.connection.execute("SELECT 1")
    { status: "ok", database: "connected" }
  rescue StandardError => e
    Rails.logger.error("Database health check failed: #{e.message}")
    { status: "error", database: "disconnected" }
  end
end
