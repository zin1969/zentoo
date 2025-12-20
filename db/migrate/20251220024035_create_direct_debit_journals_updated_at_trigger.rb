class CreateDirectDebitJournalsUpdatedAtTrigger < ActiveRecord::Migration[8.1]
  def change
    create_table :direct_debit_journals_updated_at_triggers do |t|
      t.timestamps
    end
  end
  def up
    execute <<~SQL
      CREATE TRIGGER trigger_update_updated_at_of_direct_debit_journals
      BEFORE UPDATE ON direct_debit_journals
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_with_current_timestamp();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS trigger_update_updated_at_of_direct_debit_journals ON direct_debit_journals;
    SQL
  end
end
