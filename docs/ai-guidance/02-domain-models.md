# Módulo 2: Domain Models - AI Guidance

**Estimated Time**: 1 hour
**Status**: Pending
**Dependencies**: Module 1 (Foundation)

---

## Objectives

1. Create ConversationSession model with jsonb fields
2. Create Property model with search-optimized structure
3. Create Message model for conversation history
4. Add database indexes for performance
5. Create seeds with 30 properties (CDMX, Guadalajara, Monterrey)
6. Validate model associations and constraints

---

## Schema Design

### ConversationSession Model

```ruby
# db/migrate/XXXXXX_create_conversation_sessions.rb
class CreateConversationSessions < ActiveRecord::Migration[7.0]
  def change
    create_table :conversation_sessions do |t|
      t.jsonb :lead_profile, null: false, default: {}
      t.jsonb :discrepancies, null: false, default: []  # CRITICAL: array, not object
      t.boolean :needs_human_review, default: false, null: false
      t.integer :qualification_duration_ms
      t.integer :turns_count, default: 0, null: false
      t.string :status, default: 'active', null: false

      t.timestamps
    end

    add_index :conversation_sessions, :needs_human_review
    add_index :conversation_sessions, :status
    add_index :conversation_sessions, :created_at
    # GIN index for jsonb queries (optional for demo, required for production)
    add_index :conversation_sessions, :lead_profile, using: :gin
  end
end

# app/models/conversation_session.rb
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
  scope :qualified, -> { where(status: 'qualified') }
  scope :recent, -> { order(created_at: :desc) }

  # Business logic helpers
  def qualified?
    status == 'qualified' && lead_profile.present?
  end

  def city_present?
    lead_profile['city'].present?
  end

  private

  def set_defaults
    self.lead_profile ||= {}
    self.discrepancies ||= []  # CRITICAL: Array, not null
  end
end
```

### Property Model

```ruby
# db/migrate/XXXXXX_create_properties.rb
class CreateProperties < ActiveRecord::Migration[7.0]
  def change
    create_table :properties do |t|
      t.string :title, null: false
      t.text :description
      t.decimal :price, precision: 12, scale: 2, null: false
      t.string :city, null: false
      t.string :area
      t.integer :bedrooms
      t.integer :bathrooms
      t.decimal :square_meters, precision: 8, scale: 2
      t.string :property_type  # casa, departamento, terreno
      t.jsonb :features, default: {}  # parking, amenities, etc.
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :properties, :city
    add_index :properties, :price
    add_index :properties, :bedrooms
    add_index :properties, :active
    add_index :properties, [:city, :active]  # Composite for filtering
  end
end

# app/models/property.rb
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
  scope :in_city, ->(city) { where('LOWER(city) = ?', city.to_s.downcase) }
  scope :price_range, ->(min, max) { where(price: min..max) }
  scope :min_bedrooms, ->(count) { where('bedrooms >= ?', count) }

  # Search helper (simplified for demo, production would use Elasticsearch)
  def self.search_by_profile(lead_profile)
    return none unless lead_profile['city'].present?

    query = active.in_city(lead_profile['city'])

    if lead_profile['bedrooms'].present?
      query = query.min_bedrooms(lead_profile['bedrooms'])
    end

    if lead_profile['budget'].present?
      # 20% flexibility on budget
      min = lead_profile['budget'] * 0.8
      max = lead_profile['budget'] * 1.2
      query = query.price_range(min, max)
    end

    query
  end
end
```

### Message Model

```ruby
# db/migrate/XXXXXX_create_messages.rb
class CreateMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :messages do |t|
      t.references :conversation_session, null: false, foreign_key: true
      t.string :role, null: false  # 'user' or 'assistant'
      t.text :content, null: false
      t.integer :sequence_number, null: false

      t.timestamps
    end

    add_index :messages, [:conversation_session_id, :sequence_number], unique: true
    add_index :messages, :created_at
  end
end

# app/models/message.rb
class Message < ApplicationRecord
  belongs_to :conversation_session

  validates :role, inclusion: { in: %w[user assistant] }
  validates :content, presence: true
  validates :sequence_number, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :sequence_number, uniqueness: { scope: :conversation_session_id }

  scope :ordered, -> { order(sequence_number: :asc) }
  scope :user_messages, -> { where(role: 'user') }
  scope :assistant_messages, -> { where(role: 'assistant') }
end
```

---

## Seed Data Strategy

### Requirements
- 30 properties minimum
- Distributed across 3 cities: CDMX, Guadalajara, Monterrey
- Mix of property types (casa, departamento)
- Variety of price ranges (1M - 10M MXN)
- Realistic Mexican neighborhoods

### Seed Implementation

```ruby
# db/seeds.rb
puts "Cleaning database..."
Property.destroy_all
ConversationSession.destroy_all

puts "Creating properties..."

# CDMX Properties
cdmx_areas = ['Roma Norte', 'Condesa', 'Polanco', 'Del Valle', 'Coyoacán', 'Santa Fe']
cdmx_areas.each_with_index do |area, index|
  2.times do |i|
    Property.create!(
      title: "#{i.even? ? 'Departamento' : 'Casa'} en #{area}",
      description: "Hermosa propiedad en el corazón de #{area}, CDMX. #{i.even? ? 'Departamento moderno' : 'Casa familiar'} con excelentes acabados.",
      price: rand(2_000_000..8_000_000),
      city: 'CDMX',
      area: area,
      bedrooms: rand(2..4),
      bathrooms: rand(2..3),
      square_meters: rand(80..200),
      property_type: i.even? ? 'departamento' : 'casa',
      features: {
        parking: rand(1..3),
        amenities: ['Gimnasio', 'Roof Garden', 'Seguridad 24/7'].sample(2)
      },
      active: true
    )
  end
end

# Guadalajara Properties
gdl_areas = ['Providencia', 'Chapalita', 'Zapopan', 'Tlaquepaque']
gdl_areas.each do |area|
  2.times do |i|
    Property.create!(
      title: "#{i.even? ? 'Departamento' : 'Casa'} en #{area}",
      description: "Propiedad en zona premium de #{area}, Guadalajara.",
      price: rand(1_500_000..6_000_000),
      city: 'Guadalajara',
      area: area,
      bedrooms: rand(2..4),
      bathrooms: rand(2..3),
      square_meters: rand(90..180),
      property_type: i.even? ? 'departamento' : 'casa',
      active: true
    )
  end
end

# Monterrey Properties
mty_areas = ['San Pedro', 'Cumbres', 'Valle Oriente']
mty_areas.each do |area|
  2.times do |i|
    Property.create!(
      title: "#{i.even? ? 'Departamento' : 'Casa'} en #{area}",
      description: "Exclusiva propiedad en #{area}, Monterrey.",
      price: rand(2_500_000..9_000_000),
      city: 'Monterrey',
      area: area,
      bedrooms: rand(2..4),
      bathrooms: rand(2..3),
      square_meters: rand(100..220),
      property_type: i.even? ? 'departamento' : 'casa',
      active: true
    )
  end
end

puts "Created #{Property.count} properties"
puts "  CDMX: #{Property.in_city('CDMX').count}"
puts "  Guadalajara: #{Property.in_city('Guadalajara').count}"
puts "  Monterrey: #{Property.in_city('Monterrey').count}"

# Create sample conversation session (for testing)
session = ConversationSession.create!(
  lead_profile: {
    budget: 3_000_000,
    city: 'CDMX',
    area: 'Roma Norte',
    bedrooms: 2,
    confidence: 'high'
  },
  discrepancies: [],
  needs_human_review: false,
  turns_count: 5,
  status: 'qualified'
)

Message.create!([
  { conversation_session: session, role: 'user', content: 'Busco un departamento en CDMX', sequence_number: 0 },
  { conversation_session: session, role: 'assistant', content: '¿En qué zona te gustaría?', sequence_number: 1 },
  { conversation_session: session, role: 'user', content: 'Roma Norte, 2 recámaras', sequence_number: 2 },
  { conversation_session: session, role: 'assistant', content: '¿Cuál es tu presupuesto?', sequence_number: 3 },
  { conversation_session: session, role: 'user', content: 'Hasta 3 millones', sequence_number: 4 }
])

puts "Created sample conversation session with #{session.messages.count} messages"
```

---

## Implementation Steps

1. **Generate migrations** for three models
2. **Create model files** with validations and scopes
3. **Run migrations** and verify schema
4. **Write model tests** for critical validations
5. **Create seed data** with realistic properties
6. **Verify seeds** load correctly

---

## Testing Requirements

```ruby
# spec/models/conversation_session_spec.rb
require 'rails_helper'

RSpec.describe ConversationSession, type: :model do
  describe 'validations' do
    it { should validate_inclusion_of(:status).in_array(%w[active qualified failed]) }
    it { should validate_numericality_of(:turns_count).is_greater_than_or_equal_to(0) }
  end

  describe 'associations' do
    it { should have_many(:messages).dependent(:destroy) }
  end

  describe 'defaults' do
    it 'initializes lead_profile as empty hash' do
      session = ConversationSession.new
      expect(session.lead_profile).to eq({})
    end

    it 'initializes discrepancies as empty array' do
      session = ConversationSession.new
      expect(session.discrepancies).to eq([])
    end

    it 'sets needs_human_review to false by default' do
      session = ConversationSession.new
      expect(session.needs_human_review).to be false
    end
  end

  describe '#city_present?' do
    it 'returns true when city is in lead_profile' do
      session = ConversationSession.new(lead_profile: { 'city' => 'CDMX' })
      expect(session.city_present?).to be true
    end

    it 'returns false when city is missing' do
      session = ConversationSession.new(lead_profile: {})
      expect(session.city_present?).to be false
    end
  end
end

# spec/models/property_spec.rb
require 'rails_helper'

RSpec.describe Property, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:price) }
    it { should validate_presence_of(:city) }
    it { should validate_numericality_of(:price).is_greater_than(0) }
  end

  describe '.search_by_profile' do
    let!(:cdmx_2bed) { create(:property, city: 'CDMX', bedrooms: 2, price: 3_000_000) }
    let!(:cdmx_3bed) { create(:property, city: 'CDMX', bedrooms: 3, price: 4_000_000) }
    let!(:gdl_2bed) { create(:property, city: 'Guadalajara', bedrooms: 2, price: 2_500_000) }

    it 'returns properties matching city' do
      profile = { 'city' => 'CDMX' }
      results = Property.search_by_profile(profile)
      expect(results).to include(cdmx_2bed, cdmx_3bed)
      expect(results).not_to include(gdl_2bed)
    end

    it 'returns none when city is missing' do
      profile = { 'bedrooms' => 2 }
      expect(Property.search_by_profile(profile)).to be_empty
    end
  end
end

# spec/models/message_spec.rb
require 'rails_helper'

RSpec.describe Message, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:content) }
    it { should validate_inclusion_of(:role).in_array(%w[user assistant]) }
  end

  describe 'uniqueness' do
    let(:session) { create(:conversation_session) }

    it 'prevents duplicate sequence numbers in same session' do
      create(:message, conversation_session: session, sequence_number: 0)
      duplicate = build(:message, conversation_session: session, sequence_number: 0)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:sequence_number]).to include('has already been taken')
    end
  end
end
```

---

## Critical Constraints

### JSONB Array vs Object
❌ **WRONG**: `discrepancies: null` or `discrepancies: {}`
✅ **CORRECT**: `discrepancies: []` (array of objects)

This is critical because Module 4 will push objects to the array:
```ruby
session.discrepancies << { field: 'budget', llm: 5M, heuristic: 3M }
```

### City Requirement
- City is **mandatory** for property matching
- Always validate city presence before search
- Gracefully handle missing city (return empty results)

---

## Success Criteria

- [ ] All migrations run without errors
- [ ] Seeds create exactly 30+ properties
- [ ] Model tests pass (>90% coverage)
- [ ] `rails c`: Can create session with jsonb data
- [ ] `Property.search_by_profile` works correctly
- [ ] discrepancies initializes as array, not object

---

## Next Steps

After this module, you'll have the domain foundation ready for:
- Module 3: LLM adapter with scenario management
- Module 4: LeadQualifier populating these models
- Module 5: PropertyMatcher using search_by_profile

---

**Last Updated**: 2025-12-20
