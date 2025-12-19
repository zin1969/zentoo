class CreateDebits < ActiveRecord::Migration[8.1]
  def change
    create_table :debits do |t|
      t.references :journal, foreign_key: true
      t.integer :element_type, null: false
      t.integer :account_id, null: false
      t.integer :amount, null: false
      t.references :user, foreign_key: true

      # PostgreSQL の CURRENT_TIMESTAMP を使う
      t.timestamps default: -> { "CURRENT_TIMESTAMP" }
    end

    execute <<~SQL
      ALTER TABLE debits
        ADD CONSTRAINT credit_element_type
        CHECK (element_type IN (1, 2, 3, 4, 5));
    SQL
  end
end
