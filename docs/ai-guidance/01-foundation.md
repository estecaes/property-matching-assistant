# Módulo 1: Foundation - AI Guidance

**Estimated Time**: 45 minutes
**Status**: In Progress
**Dependencies**: None (first module)

---

## Objectives

1. Rails 7 API application setup
2. PostgreSQL configuration with jsonb support
3. Docker development environment
4. RSpec testing framework
5. Structured JSON logging
6. Health check endpoint

---

## Technical Specifications

### Rails Application Setup

```bash
# Initialize Rails 7 API
rails new . --api --database=postgresql --skip-test --skip-action-cable --skip-action-mailer

# Required gems (add to Gemfile)
gem 'rspec-rails', '~> 6.0'
gem 'factory_bot_rails'
gem 'database_cleaner-active_record'
gem 'faker'
gem 'jsonapi-serializer'  # For structured responses
```

### PostgreSQL Configuration

```yaml
# config/database.yml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  host: <%= ENV.fetch("DB_HOST") { "db" } %>
  username: <%= ENV.fetch("DB_USERNAME") { "postgres" } %>
  password: <%= ENV.fetch("DB_PASSWORD") { "postgres" } %>

development:
  <<: *default
  database: property_matching_development

test:
  <<: *default
  database: property_matching_test

# IMPORTANT: Ensure jsonb support is available
# PostgreSQL 9.4+ required
```

### Docker Configuration

```dockerfile
# Dockerfile
FROM ruby:3.2.2-alpine

RUN apk add --no-cache \
  build-base \
  postgresql-dev \
  tzdata \
  nodejs \
  yarn

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]
```

```yaml
# docker-compose.yml
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  app:
    build: .
    command: bundle exec rails server -b 0.0.0.0
    volumes:
      - .:/app
      - bundle_cache:/usr/local/bundle
    ports:
      - "3000:3000"
    depends_on:
      - db
    environment:
      DB_HOST: db
      DB_USERNAME: postgres
      DB_PASSWORD: postgres
      RAILS_ENV: development

volumes:
  postgres_data:
  bundle_cache:
```

### RSpec Setup

```ruby
# spec/rails_helper.rb
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
require 'factory_bot_rails'
require 'database_cleaner/active_record'

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
```

### Structured Logging

```ruby
# config/environments/development.rb
config.log_formatter = proc do |severity, timestamp, progname, msg|
  {
    timestamp: timestamp.iso8601,
    severity: severity,
    message: msg
  }.to_json + "\n"
end

config.logger = ActiveSupport::Logger.new(STDOUT)
config.log_level = :info
```

### Health Check Endpoint

```ruby
# config/routes.rb
Rails.application.routes.draw do
  get '/health', to: 'health#show'
end

# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def show
    render json: {
      status: 'ok',
      timestamp: Time.current.iso8601,
      database: database_status,
      version: Rails.version
    }
  end

  private

  def database_status
    ActiveRecord::Base.connection.execute('SELECT 1')
    'connected'
  rescue StandardError => e
    Rails.logger.error("Database health check failed: #{e.message}")
    'disconnected'
  end
end
```

---

## Implementation Steps

### 1. Initialize Rails Application
```bash
# If not already initialized
rails new . --api --database=postgresql --skip-test --skip-action-cable --skip-action-mailer

# Or if starting fresh in existing directory
rm -rf tmp/ log/* && rails new . --api --database=postgresql --skip-test --skip-action-cable --skip-action-mailer --force
```

### 2. Configure Gemfile
Add required testing and utility gems. Keep it minimal for demo scope.

### 3. Create Docker Configuration
Create `Dockerfile` and `docker-compose.yml` as specified above.

### 4. Setup Database Configuration
Update `config/database.yml` with environment-based configuration.

### 5. Install RSpec
```bash
bundle exec rails generate rspec:install
```
Then configure `spec/rails_helper.rb` with FactoryBot and DatabaseCleaner.

### 6. Configure Structured Logging
Update `config/environments/development.rb` and `config/environments/test.rb`.

### 7. Create Health Check
Generate controller and add route for `/health` endpoint.

### 8. Verify Setup
```bash
# Build containers
docker-compose build

# Create databases
docker-compose run --rm app rails db:create

# Run tests (should have 0 examples at this point)
docker-compose run --rm app rspec

# Start server
docker-compose up

# Test health endpoint
curl http://localhost:3000/health
```

---

## Constraints & Edge Cases

### Critical Constraints
1. **API mode only**: No views, sessions, or cookies middleware
2. **PostgreSQL required**: Must support jsonb for future modules
3. **Docker mandatory**: Ensures reproducibility
4. **Structured logs**: JSON format from start, not afterthought
5. **Health check returns database status**: Not just `{status: 'ok'}`

### Common Pitfalls
❌ Using `rails g scaffold` (creates views we don't need)
❌ Forgetting to remove turbolinks/sprockets from API mode
❌ Not configuring RSpec before writing first test
❌ Plain text logs (configure JSON from start)
❌ Health check without database verification

### Edge Cases to Handle
1. **Database connection failure**: Health check should return 500 with error details
2. **Missing environment variables**: Should fail fast with clear message
3. **Port conflicts**: Document how to change default 3000 if needed

---

## Testing Requirements

### Health Endpoint Test
```ruby
# spec/requests/health_spec.rb
require 'rails_helper'

RSpec.describe 'Health Check', type: :request do
  describe 'GET /health' do
    context 'when database is connected' do
      it 'returns status ok' do
        get '/health'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('ok')
        expect(json['database']).to eq('connected')
        expect(json).to have_key('timestamp')
        expect(json).to have_key('version')
      end
    end

    context 'when database is disconnected' do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(ActiveRecord::ConnectionNotEstablished)
      end

      it 'returns status with database error' do
        get '/health'

        json = JSON.parse(response.body)
        expect(json['database']).to eq('disconnected')
      end
    end
  end
end
```

### Configuration Test
```ruby
# spec/config/logging_spec.rb
require 'rails_helper'

RSpec.describe 'Logging Configuration' do
  it 'uses JSON formatter in development' do
    output = StringIO.new
    logger = ActiveSupport::Logger.new(output)
    logger.formatter = Rails.application.config.log_formatter

    logger.info('test message')

    log_line = output.string
    parsed = JSON.parse(log_line)
    expect(parsed).to have_key('timestamp')
    expect(parsed).to have_key('severity')
    expect(parsed).to have_key('message')
  end
end
```

---

## Success Criteria

- [ ] `docker-compose up` starts application without errors
- [ ] `curl localhost:3000/health` returns JSON with database status
- [ ] `docker-compose run --rm app rspec` passes all specs
- [ ] Logs in `docker-compose logs app` are JSON formatted
- [ ] `rails routes` shows only health check endpoint
- [ ] Database connection works from container

---

## Deliverables

### Files Created
```
Gemfile (updated)
Dockerfile
docker-compose.yml
config/database.yml (updated)
config/environments/development.rb (updated)
spec/rails_helper.rb (configured)
app/controllers/health_controller.rb
spec/requests/health_spec.rb
spec/config/logging_spec.rb
```

### Commit Structure
```bash
git commit -m "[Module1] Initialize Rails 7 API with PostgreSQL

- Rails 7 API mode
- PostgreSQL configuration with environment variables
- Minimal Gemfile for foundation"

git commit -m "[Module1] Add Docker development environment

- Dockerfile with Ruby 3.2.2
- docker-compose with PostgreSQL 15
- Volume configuration for persistence"

git commit -m "[Module1] Configure RSpec and structured logging

- RSpec with FactoryBot and DatabaseCleaner
- JSON log formatter for development/test
- Health check endpoint with database status

Tests: 2 examples, 0 failures"
```

---

## Next Module Preparation

After completing this module:
1. Verify `docker-compose run --rm app rails c` works
2. Test database connection manually
3. Check that seeds can be loaded (even if empty)
4. Review docs/ai-guidance/02-domain-models.md
5. Understand jsonb requirements for ConversationSession

---

## Trade-Offs: Demo vs Production

### Demo Simplifications
- **Single database config**: Production would have read replicas
- **No monitoring**: Production needs Prometheus/Datadog
- **Basic Docker**: Production uses multi-stage builds
- **Minimal secrets**: Production uses vault/secrets manager

### Maintained Quality
✅ Structured logging (production-ready)
✅ Health checks (production pattern)
✅ Environment-based config (12-factor app)
✅ RSpec setup (matches production testing)

---

## References

- Rails API docs: https://guides.rubyonrails.org/api_app.html
- RSpec Rails: https://github.com/rspec/rspec-rails
- Docker best practices: https://docs.docker.com/develop/dev-best-practices/
- Structured logging: https://www.honeybadger.io/blog/json-logging-ruby/

---

**Last Updated**: 2025-12-20
**Module Status**: Ready for implementation
**Review Required**: After first commit
