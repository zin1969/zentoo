class AddStockSharesAndTrades < ActiveRecord::Migration[8.1]
  # 現物株を銘柄ごとに管理する（M18）。銘柄は種別「投資」の資産の口座で、取得額は口座の残高。
  # 仕訳の明細に株数（shares）を持たせ、銘柄の株数は株数の合計（借方 - 貸方）にする。株数は資産の明細だけが持てる。
  # 売却益・配当金（収益）と売却損（費用）の科目は共通科目で入れる（本番は seed をやり直さないので、ここで入れる）。
  # replace_transfer_journal は CREATE OR REPLACE なので、down では以前の定義へ戻さない（株数を持つ仕訳を断るだけで、振替の動きは同じ）
  REVENUE_NAMES = %w[配当金 株式売却益].freeze
  EXPENSE_NAMES = %w[株式売却損].freeze

  def up
    execute <<~SQL
      ALTER TABLE debits ADD COLUMN shares INTEGER;
      ALTER TABLE debits
        ADD CONSTRAINT debit_shares CHECK (shares IS NULL OR (shares > 0 AND element_type = 1));

      ALTER TABLE credits ADD COLUMN shares INTEGER;
      ALTER TABLE credits
        ADD CONSTRAINT credit_shares CHECK (shares IS NULL OR (shares > 0 AND element_type = 1));
    SQL

    REVENUE_NAMES.each { |name| insert_common_account(:revenue_accounts, name) }
    EXPENSE_NAMES.each { |name| insert_common_account(:expense_accounts, name) }

    create_function 'stocks/get_stock_holdings.sql'
    create_function 'stocks/get_last_stock_sale_date.sql'
    create_function 'stocks/create_stock_buy_journal.sql'
    create_function 'stocks/create_stock_sell_journal.sql'
    create_function 'stocks/create_opening_stock_balance_journal.sql'
    create_function 'journals/replace_transfer_journal.sql'
  end

  # 株の仕訳が残っていても戻せるが、株数は消える。科目は仕訳で使っていなければ消す
  def down
    drop_function 'create_opening_stock_balance_journal', 'DATE, INT, INT, INT, INT'
    drop_function 'create_stock_sell_journal', 'DATE, INT, INT, INT, INT, INT'
    drop_function 'create_stock_buy_journal', 'DATE, INT, INT, INT, INT, INT'
    drop_function 'get_last_stock_sale_date', 'INT'
    drop_function 'get_stock_holdings', 'INT, DATE'

    REVENUE_NAMES.each { |name| delete_unused_common_account(:revenue_accounts, 4, name) }
    EXPENSE_NAMES.each { |name| delete_unused_common_account(:expense_accounts, 5, name) }

    execute <<~SQL
      ALTER TABLE credits DROP COLUMN shares;
      ALTER TABLE debits DROP COLUMN shares;
    SQL
  end

  private

  # 同じ名前のトップレベルの共通科目があれば入れない
  def insert_common_account(table, name)
    execute <<~SQL
      INSERT INTO #{table} (name)
      SELECT #{connection.quote(name)}
       WHERE NOT EXISTS (
         SELECT 1 FROM #{table} WHERE user_id IS NULL AND parent_id IS NULL AND name = #{connection.quote(name)}
       );
    SQL
  end

  def delete_unused_common_account(table, element_type, name)
    execute <<~SQL
      DELETE FROM #{table} a
       WHERE a.user_id IS NULL
         AND a.parent_id IS NULL
         AND a.name = #{connection.quote(name)}
         AND NOT EXISTS (SELECT 1 FROM debits d WHERE d.element_type = #{element_type} AND d.account_id = a.id)
         AND NOT EXISTS (SELECT 1 FROM credits c WHERE c.element_type = #{element_type} AND c.account_id = a.id)
         AND NOT EXISTS (SELECT 1 FROM #{table} child WHERE child.parent_id = a.id);
    SQL
  end
end
