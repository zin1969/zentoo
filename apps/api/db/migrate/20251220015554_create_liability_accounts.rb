class CreateLiabilityAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :liability_accounts do |t|
      t.integer :liability_type, null: false
      t.text :name, null: false
      t.references :user, foreign_key: true

      # PostgreSQL の CURRENT_TIMESTAMP を使う
      t.timestamps default: -> { "CURRENT_TIMESTAMP" }
    end

    # liability_type
    # 1: 借入金(住宅ローン、教育ローン等)
    # 2: キャッシング
    # 3: クレジットカード払い
    execute <<~SQL
      ALTER TABLE liability_accounts
        ADD CONSTRAINT liability_account_liability_type
        CHECK (liability_type IN (1, 2, 3));
    SQL
  end
end
