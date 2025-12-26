class ConversationSession < ApplicationRecord
  has_many :messages, dependent: :destroy

  # Validations
  validates :status, inclusion: { in: %w[active qualified failed] }
  validates :turns_count, numericality: { greater_than_or_equal_to: 0 }
  validates :qualification_duration_ms, numericality: { greater_than: 0 }, allow_nil: true

  # Ensure jsonb defaults are maintained
  after_initialize :set_defaults

  # Scopes
  scope :needing_review, -> { where(needs_human_review: true) }
  scope :qualified, -> { where(status: "qualified") }
  scope :recent, -> { order(created_at: :desc) }

  # Business logic helpers
  def qualified?
    status == "qualified" && lead_profile.present?
  end

  def city_present?
    lead_profile["city"].present?
  end

  private

  def set_defaults
    self.lead_profile ||= {}
    self.discrepancies ||= []  # CRITICAL: Array, not null
  end
end
