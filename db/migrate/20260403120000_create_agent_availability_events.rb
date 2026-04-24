class CreateAgentAvailabilityEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :agent_availability_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :previous_availability
      t.integer :availability, null: false
      t.timestamps
    end

    add_index :agent_availability_events, [:account_id, :created_at]
    add_index :agent_availability_events, [:account_id, :user_id, :created_at],
              name: 'idx_agent_availability_events_account_user_created'
  end
end
