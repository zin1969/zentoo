# db/

`apps/api` に DB ロジックの管理基盤（`apps/api/db/migrate`, `apps/api/db/functions`,
`apps/api/lib/migration_helpers`）が整う前の名残。設計メモはすべて `apps/api` に移植済みで、
元の SQL は [archive/](archive/README.md) に保管している。

## 扱い方

- ここに新しい SQL を置かない。DB ロジックは
  [rails_db_logic_coding_standards.md](../docs/rules/rails_db_logic_coding_standards.md)
  （ディレクトリ構成・命名規約・migration の書き方）に従って
  `apps/api/db/functions/<domain>/` 以下に書き、`apps/api/db/migrate/` の
  migration から `create_function` ヘルパー経由で適用する。
- `archive/` の SQL は参照目的の保管で、そのまま実行・移植しない
