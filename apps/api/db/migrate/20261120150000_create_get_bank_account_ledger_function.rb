class CreateGetBankAccountLedgerFunction < ActiveRecord::Migration[8.1]
  def up
    create_function 'journals/get_bank_account_ledger.sql'
  end

  def down
    drop_function 'get_bank_account_ledger', 'INT, INT, DATE, DATE'
  end
end
