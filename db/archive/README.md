# archive

Rails アプリ（`apps/api`）に DB ロジックの管理基盤（`apps/api/db/migrate`, `apps/api/db/functions`,
`apps/api/lib/migration_helpers`）が整う前に、素の SQL / シェルスクリプトとして
プロトタイピングしていた頃の名残。すべて `apps/api/db/` 側に同等以上の内容で
置き換え済みで、コード・ドキュメントからの参照もない。

| ここにあるファイル | 置き換え先 |
|---|---|
| `create_table_*.sql`（12本） | `apps/api/db/migrate/2025122*_create_*.rb` |
| `update_updated_at_with_current_timestamp.sql` | `apps/api/db/functions/commons/update_updated_at_with_current_timestamp.sql` |
| `generate_opening_asset_balance_journal.sql` | `apps/api/db/functions/journals/create_opening_asset_balance_journal.sql`（命名・バリデーションを見直して書き直し済み） |
| `init_data.sql` | `apps/api/db/seeds/020_holidays.rb` |
| `recreate_testdb.sh` | `bin/rails db:test:prepare`（RSpec の `rails_helper.rb` が自動実行） |
| `test/opening_asset_balance.sql` | `apps/api/spec/repositories/journals/create_opening_asset_spec.rb` |

参照目的の保管のみで、削除しても実害はない。
