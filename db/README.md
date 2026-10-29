# db/

`apps/api` に DB ロジックの管理基盤（`apps/api/db/migrate`, `apps/api/db/functions`,
`apps/api/lib/migration_helpers`）が整う前の名残。現在ここに残っているのは、
**まだ `apps/api` に実装されていない機能の素の SQL 設計メモ**のみ。

| ファイル | 対象機能 |
|---|---|
| `generate_make_a_cash_deposit_journal.sql` | 現金入金仕訳の自動生成 |
| `test/make_a_cash_deposit.sql` | 上記機能の手動検証シナリオ |

クレジットカードの引き落とし仕訳（`generate_direct_debit_journal.sql` ほか）は移植済みで、`archive/` に移動した。

## 扱い方

- ここにある SQL は**設計の叩き台**であり、そのまま実行・移植しない。実装時は
  [rails_db_logic_coding_standards.md](../docs/rules/rails_db_logic_coding_standards.md)
  （ディレクトリ構成・命名規約・migration の書き方）に従って
  `apps/api/db/functions/<domain>/` 以下に書き直し、`apps/api/db/migrate/` の
  migration から `create_function` ヘルパー経由で適用する。
- 対応する migration を `apps/api` 側に作成したら、ここにある元ファイルは
  `db/archive/` へ移動する（[db/archive/README.md](archive/README.md) 参照）。
