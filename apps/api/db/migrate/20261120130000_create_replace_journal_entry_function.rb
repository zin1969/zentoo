class CreateReplaceJournalEntryFunction < ActiveRecord::Migration[8.1]
  def up
    create_function 'journals/replace_journal_entry.sql'
  end

  def down
    drop_function 'replace_journal_entry', 'INT, JSONB'
  end
end
