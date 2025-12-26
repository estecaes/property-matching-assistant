class Property < ApplicationRecord
  # Validations
  validates :title, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :city, presence: true
  validates :bedrooms, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :bathrooms, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :property_type, inclusion: { in: %w[casa departamento terreno] }, allow_nil: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :in_city, ->(city) { where("LOWER(city) = ?", city.to_s.downcase) }
  scope :price_range, ->(min, max) { where(price: min..max) }
  scope :min_bedrooms, ->(count) { where("bedrooms >= ?", count) }

  # Search helper (simplified for demo, production would use Elasticsearch)
  def self.search_by_profile(lead_profile)
    return none unless lead_profile["city"].present?

    query = active.in_city(lead_profile["city"])

    if lead_profile["bedrooms"].present?
      query = query.min_bedrooms(lead_profile["bedrooms"])
    end

    if lead_profile["budget"].present?
      # 20% flexibility on budget
      min = lead_profile["budget"] * 0.8
      max = lead_profile["budget"] * 1.2
      query = query.price_range(min, max)
    end

    query
  end
end
