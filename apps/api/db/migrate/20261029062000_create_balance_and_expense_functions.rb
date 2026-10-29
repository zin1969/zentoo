class CreateBalanceAndExpenseFunctions < ActiveRecord::Migration[8.1]
  def up
    create_function 'journals/get_account_balances.sql'
    create_function 'journals/get_monthly_expenses.sql'
  end

  def down
    drop_function 'get_monthly_expenses', 'INT, DATE'
    drop_function 'get_account_balances', 'INT, DATE'
  end
end
