class CreateCreditCards < ActiveRecord::Migration[8.1]
  def change
    create_table :credit_cards do |t|
      t.references :liability_account, foreign_key: true
      t.references :bank_account, foreign_key: { to_table: :asset_accounts }

      t.integer :cutoff_day,  null: false
      t.integer :payment_day, null: false

      t.references :user, foreign_key: true

      # PostgreSQL の CURRENT_TIMESTAMP を使う
      t.timestamps default: -> { "CURRENT_TIMESTAMP" }
    end

    # CHECK 制約（Rails DSL では書けないため SQL で追加）
    execute <<~SQL
      ALTER TABLE credit_cards
        ADD CONSTRAINT credit_cards_cutoff_day_check
        CHECK (cutoff_day BETWEEN 1 AND 31);

      ALTER TABLE credit_cards
        ADD CONSTRAINT credit_cards_payment_day_check
        CHECK (payment_day BETWEEN 1 AND 31);
    SQL
  end
end
