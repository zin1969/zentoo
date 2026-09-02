class CreateAssetAccountsUpdatedAtTrigger < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE TRIGGER trigger_update_updated_at_of_asset_accounts
      BEFORE UPDATE ON asset_accounts
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_with_current_timestamp();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS trigger_update_updated_at_of_asset_accounts ON asset_accounts;
    SQL
  end
end
