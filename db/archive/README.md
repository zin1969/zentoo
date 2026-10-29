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
| `generate_direct_debit_journal.sql`（`get_last_date_of_month` / `get_payment_date` / `generate_direct_debit_journal`） | `apps/api/db/functions/commons/get_last_date_of_month.sql`, `get_payment_date.sql`、`apps/api/db/triggers/credits/credits_after_insert.sql`（月末日の丸め、カード設定が無い場合のエラー、ユーザーの絞り込みを追加して書き直し済み） |
| `get_next_business_day.sql` | `apps/api/db/functions/commons/get_next_business_day.sql` |
| `alter_table_add_trigger_credits.sql` | `apps/api/db/triggers/credits/credits_after_insert.sql` |
| `test/use_credit_only.sql`, `test/use_cash.sql` | `apps/api/spec/db/triggers/credits_after_insert_spec.rb`, `apps/api/spec/db/functions/get_payment_date_spec.rb` |

参照目的の保管のみで、削除しても実害はない。
