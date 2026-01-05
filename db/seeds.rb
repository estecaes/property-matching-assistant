puts "Cleaning database..."
Property.destroy_all
ConversationSession.destroy_all

puts "Creating properties..."

# CDMX Properties
cdmx_areas = [ "Roma Norte", "Condesa", "Polanco", "Del Valle", "Coyoacán", "Santa Fe" ]
cdmx_areas.each_with_index do |area, index|
  2.times do |i|
    Property.create!(
      title: "#{i.even? ? 'Departamento' : 'Casa'} en #{area}",
      description: "Hermosa propiedad en el corazón de #{area}, CDMX. #{i.even? ? 'Departamento moderno' : 'Casa familiar'} con excelentes acabados.",
      price: rand(2_000_000..8_000_000),
      city: "CDMX",
      area: area,
      bedrooms: rand(2..4),
      bathrooms: rand(2..3),
      square_meters: rand(80..200),
      property_type: i.even? ? "departamento" : "casa",
      features: {
        parking: rand(1..3),
        amenities: [ "Gimnasio", "Roof Garden", "Seguridad 24/7" ].sample(2)
      },
      active: true
    )
  end
end

# Guadalajara Properties
gdl_areas = [ "Providencia", "Chapalita", "Zapopan", "Tlaquepaque" ]
gdl_areas.each do |area|
  2.times do |i|
    Property.create!(
      title: "#{i.even? ? 'Departamento' : 'Casa'} en #{area}",
      description: "Propiedad en zona premium de #{area}, Guadalajara.",
      price: rand(1_500_000..6_000_000),
      city: "Guadalajara",
      area: area,
      bedrooms: rand(2..4),
      bathrooms: rand(2..3),
      square_meters: rand(90..180),
      property_type: i.even? ? "departamento" : "casa",
      active: true
    )
  end
end

# Monterrey Properties
mty_areas = [ "San Pedro", "Cumbres", "Valle Oriente" ]
mty_areas.each do |area|
  2.times do |i|
    Property.create!(
      title: "#{i.even? ? 'Departamento' : 'Casa'} en #{area}",
      description: "Exclusiva propiedad en #{area}, Monterrey.",
      price: rand(2_500_000..9_000_000),
      city: "Monterrey",
      area: area,
      bedrooms: rand(2..4),
      bathrooms: rand(2..3),
      square_meters: rand(100..220),
      property_type: i.even? ? "departamento" : "casa",
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
    city: "CDMX",
    area: "Roma Norte",
    bedrooms: 2,
    confidence: "high"
  },
  discrepancies: [],
  needs_human_review: false,
  turns_count: 5,
  status: "qualified"
)

Message.create!([
  { conversation_session: session, role: "user", content: "Busco un departamento en CDMX", sequence_number: 0 },
  { conversation_session: session, role: "assistant", content: "¿En qué zona te gustaría?", sequence_number: 1 },
  { conversation_session: session, role: "user", content: "Roma Norte, 2 recámaras", sequence_number: 2 },
  { conversation_session: session, role: "assistant", content: "¿Cuál es tu presupuesto?", sequence_number: 3 },
  { conversation_session: session, role: "user", content: "Hasta 3 millones", sequence_number: 4 }
])

puts "Created sample conversation session with #{session.messages.count} messages"
