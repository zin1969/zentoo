class CreateGetPendingRecurringDatesFunction < ActiveRecord::Migration[8.1]
  def up
    create_function 'recurring_entries/get_pending_recurring_dates.sql'
  end

  def down
    drop_function 'get_pending_recurring_dates', 'INT, DATE'
  end
end
