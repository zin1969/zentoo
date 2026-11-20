class CreateUpdateDirectDebitDateFunction < ActiveRecord::Migration[8.1]
  def up
    create_function 'journals/update_direct_debit_date.sql'
  end

  def down
    drop_function 'update_direct_debit_date', 'INT, DATE, INT'
  end
end
