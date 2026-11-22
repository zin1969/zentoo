class CreateGetMonthlyIncomesFunction < ActiveRecord::Migration[8.1]
  def up
    create_function 'journals/get_monthly_incomes.sql'
  end

  def down
    drop_function 'get_monthly_incomes', 'INT, DATE'
  end
end
