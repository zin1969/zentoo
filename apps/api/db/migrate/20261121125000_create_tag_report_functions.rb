class CreateTagReportFunctions < ActiveRecord::Migration[8.1]
  def up
    create_function 'journals/get_tag_monthly_totals.sql'
    create_function 'journals/get_tag_items.sql'
  end

  def down
    drop_function 'get_tag_items', 'INT, INT, DATE, DATE'
    drop_function 'get_tag_monthly_totals', 'INT, INT, INT'
  end
end
