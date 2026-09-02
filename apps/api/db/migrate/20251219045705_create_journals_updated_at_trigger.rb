class CreateJournalsUpdatedAtTrigger < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE TRIGGER trigger_update_updated_at_of_journals
      BEFORE UPDATE ON journals
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_with_current_timestamp();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS trigger_update_updated_at_of_journals ON journals;
    SQL
  end
end
