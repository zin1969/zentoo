class AddDuplicateCheckToOpeningAssetBalanceJournalFunction < ActiveRecord::Migration[8.1]
  def up
    create_function 'journals/create_opening_asset_balance_journal.sql'
  end

  def down
    # CREATE OR REPLACE で上書きした関数は、以前の定義へ戻せない（git の履歴から復元する）
    raise ActiveRecord::IrreversibleMigration
  end
end
