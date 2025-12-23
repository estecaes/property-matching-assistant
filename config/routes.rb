Rails.application.routes.draw do
  # Health check endpoint
  get "/health", to: "health#show"
end
