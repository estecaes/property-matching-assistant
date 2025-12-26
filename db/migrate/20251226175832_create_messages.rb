class CreateMessages < ActiveRecord::Migration[7.2]
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
