module MigrationHelpers
  module Procedure
    include SqlLoader

    def create_procedure(path)
      execute_sql("procedures/#{path}")
    end

    def drop_procedure(name, args)
      execute <<~SQL
        DROP PROCEDURE IF EXISTS #{name}(#{args});
      SQL
    end
  end
end
