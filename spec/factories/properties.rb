FactoryBot.define do
  factory :property do
    title { "#{property_type&.capitalize || 'Casa'} en #{city}" }
    description { "Hermosa propiedad en el corazón de #{city}." }
    price { 3_000_000 }
    city { "CDMX" }
    area { "Roma Norte" }
    bedrooms { 2 }
    bathrooms { 2 }
    square_meters { 100 }
    property_type { "casa" }
    features { { "parking" => 1, "amenities" => ["Gimnasio", "Seguridad 24/7"] } }
    active { true }

    trait :departamento do
      property_type { "departamento" }
      bedrooms { 2 }
      square_meters { 80 }
    end

    trait :casa do
      property_type { "casa" }
      bedrooms { 3 }
      square_meters { 150 }
    end

    trait :in_guadalajara do
      city { "Guadalajara" }
      area { "Providencia" }
      price { 2_500_000 }
    end

    trait :in_monterrey do
      city { "Monterrey" }
      area { "San Pedro" }
      price { 4_000_000 }
    end

    trait :inactive do
      active { false }
    end
  end
end
