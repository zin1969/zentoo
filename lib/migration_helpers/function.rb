module MigrationHelpers
  module Function
    include SqlLoader

    def create_function(path)
      execute_sql("functions/#{path}")
    end

    def drop_function(name, args)
      execute <<~SQL
        DROP FUNCTION IF EXISTS #{name}(#{args});
      SQL
    end
  end
end
