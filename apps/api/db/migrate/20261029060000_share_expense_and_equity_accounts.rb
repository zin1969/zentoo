class ShareExpenseAndEquityAccounts < ActiveRecord::Migration[8.1]
  def up
    # 費用科目・資本科目は共通科目（user_id IS NULL）にする。資産・負債科目はユーザー固有のまま
    add_index :expense_accounts, "COALESCE(parent_id, 0), name",
              unique: true, where: "user_id IS NULL", name: "index_expense_accounts_on_common_name"
    add_index :equity_accounts, :name,
              unique: true, where: "user_id IS NULL", name: "index_equity_accounts_on_common_name"

    # 開発用ユーザー（masa）が持っていた科目を共通科目へ移す（ID は変わらないので既存の仕訳はそのまま使える）
    execute <<~SQL
      UPDATE expense_accounts SET user_id = NULL WHERE user_id = (SELECT id FROM users WHERE name = 'masa');
      UPDATE equity_accounts  SET user_id = NULL WHERE user_id = (SELECT id FROM users WHERE name = 'masa');
    SQL

    create_function 'journals/insert_journal_entry.sql'
    create_function 'journals/create_opening_asset_balance_journal.sql'
  end

  def down
    # 共通科目へ移した科目の元の持ち主と、上書きした関数の旧定義は復元できない
    raise ActiveRecord::IrreversibleMigration
  end
end
