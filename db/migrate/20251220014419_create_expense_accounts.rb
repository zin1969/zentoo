class CreateExpenseAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :expense_accounts do |t|
      t.references :parent,
                   foreign_key: { to_table: :expense_accounts },
                   index: true
      t.text :name, null: false
      t.references :user, foreign_key: true

      # PostgreSQL の CURRENT_TIMESTAMP を使う
      t.timestamps default: -> { "CURRENT_TIMESTAMP" }
    end
  end
end
