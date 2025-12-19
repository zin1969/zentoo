class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.text :name

      # PostgreSQL の CURRENT_TIMESTAMP を使う
      t.timestamps default: -> { "CURRENT_TIMESTAMP" }
    end
  end
end
