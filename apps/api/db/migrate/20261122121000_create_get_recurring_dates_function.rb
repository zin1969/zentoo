class CreateGetRecurringDatesFunction < ActiveRecord::Migration[8.1]
  def up
    create_function 'recurring_entries/get_recurring_dates.sql'
  end

  def down
    drop_function 'get_recurring_dates', 'INT, INT, INT, INT, DATE, DATE, DATE, DATE'
  end
end
