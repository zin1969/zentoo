class CreateCredits < ActiveRecord::Migration[8.1]
  def change
    create_table :credits do |t|
      t.references :journal, foreign_key: true
      t.integer :element_type, null: false
      t.integer :payment_method_type, null: false
      t.integer :account_id, null: false
      t.integer :amount, null: false
      t.references :user, foreign_key: true

      # PostgreSQL の CURRENT_TIMESTAMP を使う
      t.timestamps default: -> { "CURRENT_TIMESTAMP" }
    end

    execute <<~SQL
      ALTER TABLE credits
        ADD CONSTRAINT credit_element_type
        CHECK (element_type IN (1, 2, 3, 4, 5));

      ALTER TABLE credits
        ADD CONSTRAINT credit_payment_method_type
        CHECK (
          (element_type = 1 AND payment_method_type IN (1, 2, 3)) OR
          (element_type = 2 AND payment_method_type IN (1, 2, 3)) OR
          (element_type IN (3, 4, 5) AND payment_method_type = 0)
        );
    SQL
  end
end
