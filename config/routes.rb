Rails.application.routes.draw do
  # Dashboard - Root path
  root "dashboard#index"

  # Health check endpoint
  get "/health", to: "health#show"

  # Run endpoint - Main API for lead qualification and property matching
  post "/run", to: "runs#create"
end
