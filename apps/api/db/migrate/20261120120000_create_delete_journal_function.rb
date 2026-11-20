class CreateDeleteJournalFunction < ActiveRecord::Migration[8.1]
  def up
    create_function 'journals/delete_journal.sql'
  end

  def down
    drop_function 'delete_journal', 'INT, INT'
  end
end
