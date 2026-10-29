class CreateDirectDebitJournalTrigger < ActiveRecord::Migration[8.1]
  def up
    create_function 'commons/get_last_date_of_month.sql'
    create_function 'commons/get_next_business_day.sql'
    create_function 'commons/get_payment_date.sql'
    create_trigger 'credits/credits_after_insert.sql'
  end

  def down
    drop_trigger 'credits_after_insert', 'credits'
    drop_function 'credits_after_insert_fn', ''
    drop_function 'get_payment_date', 'INT, INT, DATE'
    drop_function 'get_next_business_day', 'DATE'
    drop_function 'get_last_date_of_month', 'INT, INT'
  end
end
