class AddUniqueIndexToHolidaysHoliday < ActiveRecord::Migration[8.1]
  def change
    add_index :holidays, :holiday, unique: true
  end
end
