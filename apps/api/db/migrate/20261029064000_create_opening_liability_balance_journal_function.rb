class CreateOpeningLiabilityBalanceJournalFunction < ActiveRecord::Migration[8.1]
  def up
    create_trigger 'credits/credits_after_insert.sql'
    create_function 'journals/create_opening_liability_balance_journal.sql'
  end

  def down
    # CREATE OR REPLACE で上書きしたトリガー関数は、以前の定義へ戻せない（git の履歴から復元する）
    raise ActiveRecord::IrreversibleMigration
  end
end
