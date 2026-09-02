# ActiveRecord::Migration のサブクラスに include されて使う前提
module MigrationHelpers
  module SqlLoader
    BASE_DIR = Rails.root.join('db')

    def load_sql(relative_path)
      path = BASE_DIR.join(relative_path)
      raise "SQL file not found: #{path}" unless File.exist?(path)

      File.read(path)
    end

    def execute_sql(relative_path)
      # ActiveRecord::Migration の ececute を実行
      execute load_sql(relative_path)
    end
  end
end
