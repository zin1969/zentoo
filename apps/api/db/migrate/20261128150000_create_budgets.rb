class CreateBudgets < ActiveRecord::Migration[8.1]
  # 予算と実績（M20）。予算は「対象・周期・金額」で 1 つ。ユーザーごと。
  # target_type: 1 = 費用科目（子科目も含む）、2 = タグ。科目の予算には除くタグを付けられる（食費からアルコールを外す）。
  # period_type: 1 = 週（月曜〜日曜）、2 = 月、3 = 年（1 月〜12 月）。
  # 月の予算は、毎月同じ額（amount）か、1〜12 月で月ごとに決めた額（monthly_amounts。12 個。季節で変わる電気代など）。
  # 繰り越しと額の履歴は持たない
  def up
    create_table :budgets do |t|
      t.references :user, null: false, foreign_key: true
      t.text :name, null: false
      t.integer :target_type, null: false
      # 科目は削除させない（Accounts::AccountUsage が予算も見る）。タグは予算で使っていると削除させない（Tags::TagsService）
      t.references :expense_account, foreign_key: true
      t.references :tag, foreign_key: true
      t.integer :period_type, null: false
      t.integer :amount, null: false
      t.integer :monthly_amounts, array: true

      t.timestamps default: -> { "CURRENT_TIMESTAMP" }
    end

    add_check_constraint :budgets,
                         "(target_type = 1 AND expense_account_id IS NOT NULL AND tag_id IS NULL) OR " \
                         "(target_type = 2 AND tag_id IS NOT NULL AND expense_account_id IS NULL)",
                         name: "budget_target"
    add_check_constraint :budgets, "period_type IN (1, 2, 3)", name: "budget_period_type"
    add_check_constraint :budgets, "amount >= 0", name: "budget_amount"
    add_check_constraint :budgets,
                         "monthly_amounts IS NULL OR (period_type = 2 AND CARDINALITY(monthly_amounts) = 12 " \
                         "AND 0 <= ALL(monthly_amounts) AND array_position(monthly_amounts, NULL) IS NULL)",
                         name: "budget_monthly_amounts"

    execute <<~SQL
      CREATE TRIGGER trigger_update_updated_at_of_budgets
      BEFORE UPDATE ON budgets
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_with_current_timestamp();
    SQL

    # 科目の予算から外すタグ。タグを削除すると外す指定も消える
    create_table :budget_excluded_tags do |t|
      t.references :budget, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :tag, null: false, foreign_key: { on_delete: :cascade }

      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :budget_excluded_tags, [ :budget_id, :tag_id ], unique: true

    create_function 'budgets/get_budget_report.sql'
  end

  def down
    drop_function 'get_budget_report', 'INT, DATE'
    drop_table :budget_excluded_tags
    drop_table :budgets
  end
end
