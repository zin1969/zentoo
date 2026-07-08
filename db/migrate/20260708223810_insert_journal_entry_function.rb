class InsertJournalEntryFunction < ActiveRecord::Migration[8.1]
  def up
    create_function 'journals/insert_journal_entry.sql'
  end

  def down
    drop_function 'insert_journal_entry', 'JSONB'
  end
end
