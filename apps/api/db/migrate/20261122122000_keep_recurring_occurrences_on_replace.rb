class KeepRecurringOccurrencesOnReplace < ActiveRecord::Migration[8.1]
  def up
    # 修正（削除して作り直す）しても、決まった支払いの回の記録が新しい仕訳に付いたままになるようにする
    create_function 'journals/replace_journal_entry.sql'
    create_function 'journals/replace_income_journal.sql'
  end

  def down
    # CREATE OR REPLACE で上書きした関数は、以前の定義へ戻せない（git の履歴から復元する）
    raise ActiveRecord::IrreversibleMigration
  end
end
