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
