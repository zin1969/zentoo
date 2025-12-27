module MigrationHelpers
  module Trigger
    include SqlLoader

    def create_trigger(path)
      execute_sql("triggers/#{path}")
    end

    def drop_trigger(trigger_name, table)
      execute <<~SQL
        DROP TRIGGER IF EXISTS #{trigger_name} ON #{table};
      SQL
    end
  end
end
