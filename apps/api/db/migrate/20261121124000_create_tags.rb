class CreateTags < ActiveRecord::Migration[8.1]
  def up
    # タグは「何のために使ったか」（勉強・娯楽など）。ユーザーごとで、名前はユーザーの中で重ならない
    create_table :tags do |t|
      t.references :user, null: false, foreign_key: true
      t.text :name, null: false

      t.timestamps default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :tags, [ :user_id, :name ], unique: true

    execute <<~SQL
      CREATE TRIGGER trigger_update_updated_at_of_tags
      BEFORE UPDATE ON tags
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_with_current_timestamp();
    SQL

    # 明細（借方の 1 行）とタグは多対多。明細やタグが消えたら、組も消える
    create_table :debit_tags do |t|
      t.references :debit, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :tag, null: false, foreign_key: { on_delete: :cascade }

      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :debit_tags, [ :debit_id, :tag_id ], unique: true

    create_function 'journals/insert_journal_entry.sql'
  end

  def down
    # CREATE OR REPLACE で上書きした関数は、以前の定義へ戻せない（git の履歴から復元する）
    raise ActiveRecord::IrreversibleMigration
  end
end
