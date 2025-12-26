class CreateConversationSessions < ActiveRecord::Migration[7.2]
  def change
    create_table :conversation_sessions do |t|
      t.jsonb :lead_profile, null: false, default: {}
      t.jsonb :discrepancies, null: false, default: []  # CRITICAL: array, not object
      t.boolean :needs_human_review, default: false, null: false
      t.integer :qualification_duration_ms
      t.integer :turns_count, default: 0, null: false
      t.string :status, default: "active", null: false

      t.timestamps
    end

    add_index :conversation_sessions, :needs_human_review
    add_index :conversation_sessions, :status
    add_index :conversation_sessions, :created_at
    # GIN index for jsonb queries (optional for demo, required for production)
    add_index :conversation_sessions, :lead_profile, using: :gin
  end
end
