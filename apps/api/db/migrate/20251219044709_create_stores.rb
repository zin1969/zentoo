class CreateStores < ActiveRecord::Migration[8.1]
  def change
    create_table :stores do |t|
      t.text :name

      # PostgreSQL の CURRENT_TIMESTAMP を使う
      t.timestamps default: -> { "CURRENT_TIMESTAMP" }
    end
  end
end
