class CreateRecurringEntries < ActiveRecord::Migration[8.1]
  def up
    # 決まった支払い（家賃・サブスク・給料など）。自動では登録せず、回ごとに確かめてから仕訳にする。
    # kind: 1 = 支出（借方が費用、貸方が支払い方法の資産か負債）、2 = 収入（借方が入金先の資産、貸方が収益）。
    # 科目は仕訳と同じく、種別（element_type）と ID で持つ（科目のテーブルが種別ごとに分かれているため外部キーは張らない）
    create_table :recurring_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.text :name, null: false
      t.integer :kind, null: false
      t.text :store_name
      t.text :item_name
      # 目安の金額。登録のときに直せる
      t.integer :amount, null: false
      t.integer :debit_account_id, null: false
      t.integer :credit_element_type, null: false
      t.integer :credit_account_id, null: false
      # くり返し。interval_unit: 1 = 月単位（開始日の月から interval_count ヶ月ごとの day_of_month 日。31 は月末）、
      # 2 = 週単位（interval_count 週ごとの weekday 曜日。0 = 日曜）。毎年は月単位の 12 ヶ月ごと
      t.integer :interval_unit, null: false
      t.integer :interval_count, null: false
      t.integer :day_of_month
      t.integer :weekday
      t.date :start_date, null: false
      t.date :end_date

      t.timestamps default: -> { "CURRENT_TIMESTAMP" }
    end

    add_check_constraint :recurring_entries, "kind IN (1, 2)", name: "recurring_entry_kind"
    add_check_constraint :recurring_entries,
                         "(kind = 1 AND credit_element_type IN (1, 2)) OR (kind = 2 AND credit_element_type = 4)",
                         name: "recurring_entry_credit_element_type"
    add_check_constraint :recurring_entries, "amount > 0", name: "recurring_entry_amount"
    add_check_constraint :recurring_entries, "interval_count BETWEEN 1 AND 12", name: "recurring_entry_interval_count"
    add_check_constraint :recurring_entries,
                         "(interval_unit = 1 AND day_of_month BETWEEN 1 AND 31 AND weekday IS NULL) OR " \
                         "(interval_unit = 2 AND weekday BETWEEN 0 AND 6 AND day_of_month IS NULL)",
                         name: "recurring_entry_schedule"
    add_check_constraint :recurring_entries, "end_date IS NULL OR end_date >= start_date",
                         name: "recurring_entry_period"

    execute <<~SQL
      CREATE TRIGGER trigger_update_updated_at_of_recurring_entries
      BEFORE UPDATE ON recurring_entries
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_with_current_timestamp();
    SQL

    # 回ごとの記録。登録した仕訳か、飛ばしたか（どちらか一方）。同じ回は 1 つだけ。
    # 登録した仕訳を削除すると記録も消え、その回は未登録に戻る
    create_table :recurring_entry_occurrences do |t|
      t.references :recurring_entry, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.date :scheduled_date, null: false
      t.references :journal, foreign_key: { on_delete: :cascade }
      t.boolean :skipped, null: false, default: false

      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :recurring_entry_occurrences, [ :recurring_entry_id, :scheduled_date ], unique: true
    add_check_constraint :recurring_entry_occurrences, "(journal_id IS NOT NULL) <> skipped",
                         name: "recurring_entry_occurrence_journal_or_skipped"
  end

  def down
    drop_table :recurring_entry_occurrences
    drop_table :recurring_entries
  end
end
