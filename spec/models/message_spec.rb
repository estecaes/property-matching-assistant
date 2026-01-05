require "rails_helper"

RSpec.describe Message, type: :model do
  describe "associations" do
    it "belongs to conversation_session" do
      session = create(:conversation_session)
      message = create(:message, conversation_session: session)
      expect(message.conversation_session).to eq(session)
    end
  end

  describe "validations" do
    it "validates presence of content" do
      expect(build(:message, content: nil)).not_to be_valid
      expect(build(:message, content: "")).not_to be_valid
      expect(build(:message, content: "Hello")).to be_valid
    end

    it "validates role inclusion" do
      expect(build(:message, role: "user")).to be_valid
      expect(build(:message, role: "assistant")).to be_valid
      expect(build(:message, role: "system")).not_to be_valid
      expect(build(:message, role: "invalid")).not_to be_valid
    end

    it "validates presence of sequence_number" do
      expect(build(:message, sequence_number: nil)).not_to be_valid
      expect(build(:message, sequence_number: 0)).to be_valid
    end

    it "validates sequence_number is non-negative" do
      expect(build(:message, sequence_number: 0)).to be_valid
      expect(build(:message, sequence_number: 5)).to be_valid
      expect(build(:message, sequence_number: -1)).not_to be_valid
    end
  end

  describe "uniqueness" do
    let(:session) { create(:conversation_session) }

    it "prevents duplicate sequence numbers in same session" do
      create(:message, conversation_session: session, sequence_number: 0)
      duplicate = build(:message, conversation_session: session, sequence_number: 0)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:sequence_number]).to include("has already been taken")
    end

    it "allows same sequence number in different sessions" do
      session2 = create(:conversation_session)
      create(:message, conversation_session: session, sequence_number: 0)
      message2 = build(:message, conversation_session: session2, sequence_number: 0)

      expect(message2).to be_valid
    end
  end

  describe "scopes" do
    let(:session) { create(:conversation_session) }
    let!(:user_msg1) { create(:message, :user, conversation_session: session, sequence_number: 0) }
    let!(:assistant_msg) { create(:message, :assistant, conversation_session: session, sequence_number: 1) }
    let!(:user_msg2) { create(:message, :user, conversation_session: session, sequence_number: 2) }

    describe ".ordered" do
      it "returns messages ordered by sequence_number" do
        expect(Message.ordered.pluck(:sequence_number)).to eq([ 0, 1, 2 ])
      end
    end

    describe ".user_messages" do
      it "returns only user messages" do
        expect(Message.user_messages).to include(user_msg1, user_msg2)
        expect(Message.user_messages).not_to include(assistant_msg)
      end
    end

    describe ".assistant_messages" do
      it "returns only assistant messages" do
        expect(Message.assistant_messages).to include(assistant_msg)
        expect(Message.assistant_messages).not_to include(user_msg1, user_msg2)
      end
    end
  end
end
