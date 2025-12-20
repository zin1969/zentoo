class CreateHolidayTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :holiday_types do |t|
      t.text :name, null: false

      # PostgreSQL の CURRENT_TIMESTAMP を使う
      t.timestamps default: -> { "CURRENT_TIMESTAMP" }
    end
  end
end
