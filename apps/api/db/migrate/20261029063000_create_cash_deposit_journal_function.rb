class CreateCashDepositJournalFunction < ActiveRecord::Migration[8.1]
  def up
    create_function 'journals/create_cash_deposit_journal.sql'
  end

  def down
    drop_function 'create_cash_deposit_journal', 'DATE, INT, INT, INT'
  end
end
