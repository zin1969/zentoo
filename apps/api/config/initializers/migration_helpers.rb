ActiveSupport.on_load(:active_record) do
  ActiveRecord::Migration.include MigrationHelpers::SqlLoader
  ActiveRecord::Migration.include MigrationHelpers::Function
  ActiveRecord::Migration.include MigrationHelpers::Procedure
  ActiveRecord::Migration.include MigrationHelpers::Trigger
end
