require 'rails_helper'

RSpec.describe 'POST /run', type: :request do
  let!(:properties) do
    [
      # CDMX properties for budget_seeker scenario
      create(:property,
        title: 'Departamento en Roma Norte',
        price: 2_950_000,
        city: 'CDMX',
        area: 'Roma Norte',
        bedrooms: 2,
        bathrooms: 2,
        property_type: 'departamento'
      ),
      create(:property,
        title: 'Departamento en Roma Norte 2',
        price: 3_100_000,
        city: 'CDMX',
        area: 'Roma Norte',
        bedrooms: 2,
        bathrooms: 2,
        property_type: 'departamento'
      ),
      # Guadalajara properties (won't match CDMX searches)
      create(:property,
        title: 'Casa en Guadalajara',
        price: 3_000_000,
        city: 'Guadalajara',
        area: 'Providencia',
        bedrooms: 3,
        bathrooms: 2,
        property_type: 'casa'
      )
    ]
  end

  before do
    host! 'localhost'
  end

  context 'with budget_seeker scenario' do
    it 'returns successful qualification with matches' do
      post '/run', headers: { 'X-Scenario' => 'budget_seeker' }

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['session_id']).to be_present
      expect(json['lead_profile']['budget']).to eq(3_000_000)
      expect(json['lead_profile']['city']).to eq('CDMX')
      expect(json['lead_profile']['bedrooms']).to eq(2)
      expect(json['matches']).not_to be_empty
      expect(json['matches'].size).to be <= 3
      expect(json['needs_human_review']).to be false
      expect(json['discrepancies']).to be_empty
      expect(json['metrics']['qualification_duration_ms']).to be > 0
      expect(json['metrics']['turns_count']).to be > 0
      expect(json['status']).to eq('qualified')
    end

    it 'creates ConversationSession with messages' do
      expect {
        post '/run', headers: { 'X-Scenario' => 'budget_seeker' }
      }.to change(ConversationSession, :count).by(1)
       .and change(Message, :count).by_at_least(1)

      session = ConversationSession.last
      expect(session.messages.count).to be > 0
      expect(session.turns_count).to eq(session.messages.count)
    end

    it 'returns matches sorted by score descending' do
      post '/run', headers: { 'X-Scenario' => 'budget_seeker' }

      json = JSON.parse(response.body)
      scores = json['matches'].map { |m| m['score'] }
      expect(scores).to eq(scores.sort.reverse)
    end
  end

  context 'with budget_mismatch scenario' do
    it 'returns discrepancies and needs_human_review' do
      post '/run', headers: { 'X-Scenario' => 'budget_mismatch' }

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['needs_human_review']).to be true
      expect(json['discrepancies']).not_to be_empty

      budget_disc = json['discrepancies'].find { |d| d['field'] == 'budget' }
      expect(budget_disc).to be_present
      expect(budget_disc['diff_pct']).to be > 20
      expect(budget_disc['severity']).to eq('high')
    end

    it 'uses defensive merge strategy (heuristic value in profile)' do
      post '/run', headers: { 'X-Scenario' => 'budget_mismatch' }

      json = JSON.parse(response.body)
      # Heuristic extracts 3M (last mention), LLM extracts 5M (first mention)
      # Defensive strategy: prefer heuristic on conflict
      expect(json['lead_profile']['budget']).to eq(3_000_000)
    end
  end

  context 'with phone_vs_budget scenario' do
    it 'correctly extracts budget, not phone' do
      post '/run', headers: { 'X-Scenario' => 'phone_vs_budget' }

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['lead_profile']['budget']).to eq(3_000_000)
      expect(json['lead_profile']['budget']).not_to eq(5_512_345_678)
    end

    it 'does not create discrepancy for phone number' do
      post '/run', headers: { 'X-Scenario' => 'phone_vs_budget' }

      json = JSON.parse(response.body)
      # Should not have high discrepancy since heuristic uses keyword proximity
      high_discrepancies = json['discrepancies'].select { |d| d['severity'] == 'high' }
      expect(high_discrepancies).to be_empty
    end
  end

  context 'with missing_city scenario' do
    it 'returns empty matches when city is missing' do
      post '/run', headers: { 'X-Scenario' => 'missing_city' }

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['matches']).to be_empty
      expect(json['lead_profile']['city']).to be_nil
    end
  end

  context 'without scenario header' do
    it 'returns ok with empty messages' do
      post '/run'

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['session_id']).to be_present
      expect(json['metrics']['turns_count']).to eq(0)
    end
  end

  context 'when errors occur' do
    before do
      allow(LeadQualifier).to receive(:call).and_raise(StandardError, 'Test error')
    end

    it 'returns error response with 500 status' do
      post '/run', headers: { 'X-Scenario' => 'budget_seeker' }

      expect(response).to have_http_status(:internal_server_error)

      json = JSON.parse(response.body)
      expect(json['error']).to eq('Internal server error')
      expect(json['message']).to eq('Test error')
    end

    it 'logs structured error JSON' do
      expect(Rails.logger).to receive(:error) do |log_message|
        log_data = JSON.parse(log_message)
        expect(log_data['event']).to eq('run_error')
        expect(log_data['error_class']).to eq('StandardError')
        expect(log_data['error_message']).to eq('Test error')
        expect(log_data['backtrace']).to be_an(Array)
      end

      post '/run', headers: { 'X-Scenario' => 'budget_seeker' }
    end
  end

  context 'response structure validation' do
    it 'always includes required fields' do
      post '/run', headers: { 'X-Scenario' => 'budget_seeker' }

      json = JSON.parse(response.body)

      # Required top-level fields
      expect(json).to have_key('session_id')
      expect(json).to have_key('lead_profile')
      expect(json).to have_key('matches')
      expect(json).to have_key('needs_human_review')
      expect(json).to have_key('discrepancies')
      expect(json).to have_key('metrics')
      expect(json).to have_key('status')

      # Required metrics fields
      expect(json['metrics']).to have_key('qualification_duration_ms')
      expect(json['metrics']).to have_key('turns_count')

      # Arrays should always be present (even if empty)
      expect(json['matches']).to be_an(Array)
      expect(json['discrepancies']).to be_an(Array)
    end
  end
end
