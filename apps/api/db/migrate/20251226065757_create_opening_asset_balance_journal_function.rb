class CreateOpeningAssetBalanceJournalFunction < ActiveRecord::Migration[8.1]
  def up
    create_function 'journals/create_opening_asset_balance_journal.sql'
  end

  def down
    drop_function 'create_opening_asset_balance_journal',
                  'DATE, INT, INT, INT, INT'
  end
end
