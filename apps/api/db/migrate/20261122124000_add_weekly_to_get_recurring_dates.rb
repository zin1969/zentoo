class AddWeeklyToGetRecurringDates < ActiveRecord::Migration[8.1]
  def up
    # 週単位（N 週ごとの何曜日）の予定日も出す
    create_function 'recurring_entries/get_recurring_dates.sql'
  end

  def down
    # CREATE OR REPLACE で上書きした関数は、以前の定義へ戻せない（git の履歴から復元する）
    raise ActiveRecord::IrreversibleMigration
  end
end
