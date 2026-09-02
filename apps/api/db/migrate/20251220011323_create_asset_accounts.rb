class CreateAssetAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :asset_accounts do |t|
      t.integer :asset_type, null: false
      t.text :name, null: false
      t.references :user, foreign_key: true

      # PostgreSQL の CURRENT_TIMESTAMP を使う
      t.timestamps default: -> { "CURRENT_TIMESTAMP" }
    end

    # asset_type
    # 1: 現金
    # 2: 預貯金（銀行、信用金庫、郵貯等）
    # 3: eManey
    execute <<~SQL
      ALTER TABLE asset_accounts
        ADD CONSTRAINT asset_account_asset_type
        CHECK (asset_type IN (1, 2, 3));
    SQL
  end
end
