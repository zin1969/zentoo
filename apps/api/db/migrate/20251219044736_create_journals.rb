class CreateJournals < ActiveRecord::Migration[8.1]
  def change
    create_table :journals do |t|
      t.date :journal_dt, null: false
      t.references :store, foreign_key: true
      t.text :store_name
      t.references :user, foreign_key: true

      # PostgreSQL の CURRENT_TIMESTAMP を使う
      t.timestamps default: -> { "CURRENT_TIMESTAMP" }
    end
  end
end
