class KeepOverriddenPaymentDateOnReplaceJournalEntry < ActiveRecord::Migration[8.1]
  def up
    create_function 'journals/replace_journal_entry.sql'
  end

  def down
    # CREATE OR REPLACE で上書きした関数は、以前の定義へ戻せない（git の履歴から復元する）
    raise ActiveRecord::IrreversibleMigration
  end
end
