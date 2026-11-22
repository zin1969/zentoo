class CreateIncomeJournalFunctions < ActiveRecord::Migration[8.1]
  def up
    create_function 'journals/create_income_journal.sql'
    create_function 'journals/replace_income_journal.sql'
  end

  def down
    drop_function 'replace_income_journal', 'INT, DATE, INT, INT, INT, TEXT, INT'
    drop_function 'create_income_journal', 'DATE, INT, INT, INT, TEXT, INT'
  end
end
