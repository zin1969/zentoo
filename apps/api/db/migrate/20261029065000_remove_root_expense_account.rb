class RemoveRootExpenseAccount < ActiveRecord::Migration[8.1]
  ROOT_IDS = "SELECT id FROM expense_accounts WHERE name = 'root' AND parent_id IS NULL"

  def up
    # ダミーの root 科目を無くし、その子をトップレベル（parent_id IS NULL）にする
    used = select_value(<<~SQL)
      SELECT 1 FROM debits  WHERE element_type = 5 AND account_id IN (#{ROOT_IDS})
      UNION ALL
      SELECT 1 FROM credits WHERE element_type = 5 AND account_id IN (#{ROOT_IDS})
      LIMIT 1
    SQL
    raise "root expense account is used by journals" if used

    execute "UPDATE expense_accounts SET parent_id = NULL WHERE parent_id IN (#{ROOT_IDS})"
    execute "DELETE FROM expense_accounts WHERE id IN (#{ROOT_IDS})"
  end

  def down
    # 削除した root 科目と、その子の付け替えは復元できない
    raise ActiveRecord::IrreversibleMigration
  end
end
