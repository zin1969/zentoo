class CreateEquityAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :equity_accounts do |t|
      t.text :name, null: false
      t.references :user, foreign_key: true

      # PostgreSQL の CURRENT_TIMESTAMP を使う
      t.timestamps default: -> { "CURRENT_TIMESTAMP" }
    end
  end
end
