class Message < ApplicationRecord
  belongs_to :conversation_session

  validates :role, inclusion: { in: %w[user assistant] }
  validates :content, presence: true
  validates :sequence_number, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :sequence_number, uniqueness: { scope: :conversation_session_id }

  scope :ordered, -> { order(sequence_number: :asc) }
  scope :user_messages, -> { where(role: "user") }
  scope :assistant_messages, -> { where(role: "assistant") }
end
