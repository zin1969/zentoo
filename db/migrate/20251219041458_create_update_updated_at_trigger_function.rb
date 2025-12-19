class CreateUpdateUpdatedAtTriggerFunction < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION update_updated_at_with_current_timestamp()
      RETURNS TRIGGER AS $$
      BEGIN
        NEW.updated_at = CURRENT_TIMESTAMP;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  def down
    execute <<~SQL
      DROP FUNCTION IF EXISTS update_updated_at_with_current_timestamp();
    SQL
  end
end
