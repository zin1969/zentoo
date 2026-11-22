class CreateTransferJournalFunctions < ActiveRecord::Migration[8.1]
  def up
    create_function 'journals/create_transfer_journal.sql'
    create_function 'journals/replace_transfer_journal.sql'
  end

  def down
    drop_function 'replace_transfer_journal', 'INT, DATE, INT, INT, INT, INT, TEXT, INT'
    drop_function 'create_transfer_journal', 'DATE, INT, INT, INT, INT, TEXT, INT'
  end
end
