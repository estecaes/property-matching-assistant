require "rails_helper"

RSpec.describe ConversationSession, type: :model do
  describe "validations" do
    it "validates status inclusion" do
      expect(build(:conversation_session, status: "active")).to be_valid
      expect(build(:conversation_session, status: "qualified")).to be_valid
      expect(build(:conversation_session, status: "failed")).to be_valid
      expect(build(:conversation_session, status: "invalid")).not_to be_valid
    end

    it "validates turns_count is non-negative" do
      expect(build(:conversation_session, turns_count: 0)).to be_valid
      expect(build(:conversation_session, turns_count: 5)).to be_valid
      expect(build(:conversation_session, turns_count: -1)).not_to be_valid
    end

    it "validates qualification_duration_ms is positive when present" do
      expect(build(:conversation_session, qualification_duration_ms: nil)).to be_valid
      expect(build(:conversation_session, qualification_duration_ms: 1500)).to be_valid
      expect(build(:conversation_session, qualification_duration_ms: 0)).not_to be_valid
      expect(build(:conversation_session, qualification_duration_ms: -100)).not_to be_valid
    end
  end

  describe "associations" do
    it "has many messages" do
      session = create(:conversation_session)
      message1 = create(:message, conversation_session: session, sequence_number: 0)
      message2 = create(:message, conversation_session: session, sequence_number: 1)

      expect(session.messages).to include(message1, message2)
    end

    it "destroys dependent messages" do
      session = create(:conversation_session)
      create(:message, conversation_session: session, sequence_number: 0)

      expect { session.destroy }.to change(Message, :count).by(-1)
    end
  end

  describe "defaults" do
    it "initializes lead_profile as empty hash" do
      session = ConversationSession.new
      expect(session.lead_profile).to eq({})
    end

    it "initializes discrepancies as empty array" do
      session = ConversationSession.new
      expect(session.discrepancies).to eq([])
    end

    it "sets needs_human_review to false by default" do
      session = ConversationSession.new
      expect(session.needs_human_review).to be false
    end

    it "sets status to active by default" do
      session = ConversationSession.new
      expect(session.status).to eq("active")
    end

    it "sets turns_count to 0 by default" do
      session = ConversationSession.new
      expect(session.turns_count).to eq(0)
    end
  end

  describe "scopes" do
    let!(:review_session) { create(:conversation_session, :needs_review) }
    let!(:qualified_session) { create(:conversation_session, :qualified) }
    let!(:active_session) { create(:conversation_session) }

    describe ".needing_review" do
      it "returns only sessions needing human review" do
        expect(ConversationSession.needing_review).to include(review_session)
        expect(ConversationSession.needing_review).not_to include(qualified_session, active_session)
      end
    end

    describe ".qualified" do
      it "returns only qualified sessions" do
        expect(ConversationSession.qualified).to include(qualified_session)
        expect(ConversationSession.qualified).not_to include(review_session, active_session)
      end
    end

    describe ".recent" do
      it "orders by created_at descending" do
        expect(ConversationSession.recent.first).to eq(active_session)
      end
    end
  end

  describe "#qualified?" do
    it "returns true when status is qualified and lead_profile present" do
      session = create(:conversation_session, :qualified)
      expect(session.qualified?).to be true
    end

    it "returns false when status is not qualified" do
      session = create(:conversation_session, status: "active", lead_profile: { "city" => "CDMX" })
      expect(session.qualified?).to be false
    end

    it "returns false when lead_profile is empty" do
      session = create(:conversation_session, status: "qualified", lead_profile: {})
      expect(session.qualified?).to be false
    end
  end

  describe "#city_present?" do
    it "returns true when city is in lead_profile" do
      session = create(:conversation_session, lead_profile: { "city" => "CDMX" })
      expect(session.city_present?).to be true
    end

    it "returns false when city is missing" do
      session = create(:conversation_session, lead_profile: {})
      expect(session.city_present?).to be false
    end

    it "returns false when city is nil" do
      session = create(:conversation_session, lead_profile: { "city" => nil })
      expect(session.city_present?).to be false
    end

    it "returns false when city is empty string" do
      session = create(:conversation_session, lead_profile: { "city" => "" })
      expect(session.city_present?).to be false
    end
  end

  describe "jsonb array vs object" do
    it "allows pushing objects to discrepancies array" do
      session = create(:conversation_session)
      session.discrepancies << { "field" => "budget", "llm" => 5_000_000, "heuristic" => 3_000_000 }
      session.save!

      expect(session.reload.discrepancies).to be_an(Array)
      expect(session.discrepancies.first["field"]).to eq("budget")
    end
  end
end
