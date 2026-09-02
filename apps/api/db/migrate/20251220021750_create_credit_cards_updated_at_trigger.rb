class CreateCreditCardsUpdatedAtTrigger < ActiveRecord::Migration[8.1]
  def change
    create_table :credit_cards_updated_at_triggers do |t|
      t.timestamps
    end
  end
  def up
    execute <<~SQL
      CREATE TRIGGER trigger_update_updated_at_of_credit_cards
      BEFORE UPDATE ON credit_cards
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_with_current_timestamp();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS trigger_update_updated_at_of_credit_cards ON credit_cards;
    SQL
  end
end
