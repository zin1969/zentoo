class CreateRevenueAccounts < ActiveRecord::Migration[8.1]
  # 本番は DB を新しく作ったときにしか seed が走らないので、最初の科目はここで入れる
  INITIAL_NAMES = %w[給与 賞与 雑収入].freeze

  def up
    # 収益科目。費用科目と同じく全ユーザー共通（user_id IS NULL）で、親子の 2 階層
    create_table :revenue_accounts do |t|
      t.references :parent, foreign_key: { to_table: :revenue_accounts }, index: true
      t.text :name, null: false
      t.references :user, foreign_key: true

      t.timestamps default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :revenue_accounts, "COALESCE(parent_id, 0), name",
              unique: true, where: "user_id IS NULL", name: "index_revenue_accounts_on_common_name"

    execute <<~SQL
      CREATE TRIGGER trigger_update_updated_at_of_revenue_accounts
      BEFORE UPDATE ON revenue_accounts
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_with_current_timestamp();
    SQL

    INITIAL_NAMES.each do |name|
      execute "INSERT INTO revenue_accounts (name) VALUES (#{connection.quote(name)})"
    end
  end

  def down
    drop_table :revenue_accounts
  end
end
