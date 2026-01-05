class CreateProperties < ActiveRecord::Migration[7.2]
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
    add_index :properties, [ :city, :active ]  # Composite for filtering
  end
end
