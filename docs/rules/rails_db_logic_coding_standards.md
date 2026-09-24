# Rails 8 + PostgreSQL
## DB ロジック管理 コーディング規約（実務完成版）

---

## 1. 目的
本規約は、Rails 8 環境において PostgreSQL の **function / procedure / trigger / view** を  
**安全・可読・長期運用可能**な形で管理することを目的とする。

- DB ロジックの属人化を防ぐ
- migration の事故を防ぐ
- レビュー・保守性を高める

---

## 2. 基本方針（最重要）

### 2.1 責務分離

| レイヤ | 責務 |
|---|---|
| Ruby (Rails) | ユースケース制御、トランザクション境界 |
| PostgreSQL | データ整合性、集約ロジック、自動処理 |
| Migration | DB オブジェクトの適用・削除のみ |

Ruby 側から本規約の function / procedure を呼び出す実装（Repository）の規約は [rails_api_coding_standards.md](rails_api_coding_standards.md) §4.1 repositories を参照。

### 2.2 Migration に SQL を直書きしない

❌ NG
```ruby
execute <<~SQL
  CREATE FUNCTION ...
SQL
```

✅ OK
```ruby
create_function 'journals/generate_opening_asset_balance_journal.sql'
```

---

## 3. ディレクトリ構成（必須）

```text
db/
├─ functions/
│  ├─ journals/
│  └─ common/
├─ procedures/
│  └─ journals/
├─ triggers/
│  ├─ credits/
│  └─ journals/
├─ views/
└─ migrate/
```

**ルール**

- DB オブジェクトの種類ごとに分離する
- ドメイン or テーブル単位でサブディレクトリを切る
- ファイル名から影響範囲が分かること

---

## 4. 命名規約

### 4.1 Function

| 項目     | ルール                            |
| ------ | ------------------------------ |
| Prefix | `create_` / `calc_` / `get_` |
| 命名     | 動作が明確に分かる名前                    |
| 戻り値    | `RETURNS` を必ず明示                |

**例**

```text
create_opening_asset_balance_journal
calc_tax_amount
get_account_balance
```

### 4.2 Procedure

| 項目       | ルール                     |
| -------- | ----------------------- |
| Prefix   | `process_` / `execute_` |
| 用途       | 副作用あり・複数操作              |
| トランザクション | DB 側で完結させる              |

**例**

```text
process_monthly_closing
execute_recalculate_balances
```

### 4.3 Trigger / Trigger Function

**trigger function**

```text
<table>_<timing>_<event>_fn
```

**例**

```text
credits_after_insert_fn
journals_before_update_fn
```

**trigger**

```text
<table>_<timing>_<event>
```

**例**

```text
credits_after_insert
```

---

## 5. SQL ファイル記述ルール

### 5.1 Function / Procedure

```sql
CREATE OR REPLACE FUNCTION ...
LANGUAGE plpgsql
AS $$
DECLARE
  -- 変数宣言
BEGIN
  -- 処理
  RETURN ...;
END;
$$;
```

**ルール**

- `CREATE OR REPLACE` を必ず使用する
- `DECLARE` は省略しない
- マジックナンバーは `CONSTANT` にする
- コメントは「何を」ではなく「なぜ」を書く

### 5.2 Trigger SQL（必須形式）

```sql
CREATE OR REPLACE FUNCTION xxx_fn()
RETURNS trigger AS $$
BEGIN
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS xxx ON table_name;

CREATE TRIGGER xxx
AFTER INSERT ON table_name
FOR EACH ROW
EXECUTE FUNCTION xxx_fn();
```

---

## 6. Migration の書き方

### 6.1 up / down を必ず分ける

```ruby
class CreateFooFunction < ActiveRecord::Migration[8.1]
  def up
    create_function 'journals/foo.sql'
  end

  def down
    drop_function 'foo', 'INT, DATE'
  end
end
```

### 6.2 Migration 記述ルール

- 1 migration は 10 行以内を目安
- 条件分岐を書かない
- ビジネスロジックを書かない
- SQL の内容は SQL ファイルに集約する

---

## 7. 共通ヘルパー利用ルール

### 7.1 使用可能メソッド

| 種別      | メソッド                             |
| --------- | ------------------------------------ |
| Function  | `create_function`, `drop_function`   |
| Procedure | `create_procedure`, `drop_procedure` |
| Trigger   | `create_trigger`, `drop_trigger`     |

### 7.2 `execute_sql` の直接利用

- 原則禁止
- 新種別 DB オブジェクト対応など、やむを得ない場合のみ可

### 7.3 保存ディレクトリ構成

```text
lib
└── migration_helpers
    ├── function.rb
    ├── procedure.rb
    ├── sql_loader.rb
    └── trigger.rb
```

## 8. Rails 設定（必須）

### 8.1 Schema 管理

```ruby
config.active_record.schema_format = :sql
```

### 8.2 Autoload / Zeitwerk

```ruby
config.autoload_lib(ignore: %w[assets tasks])
```

- `config.autoload_paths` は使用しない
- `require` は書かない
- Zeitwerk にロードを任せる

---

## 9. 変更・運用ルール（事故防止）

### 9.1 本番適用済み Migration

- **編集禁止**
- 修正は必ず新 migration で行う

### 9.2 Trigger 変更時

- 影響テーブル
- 発火タイミング
- 副作用

を PR に明記すること

---

## 10. テスト指針（推奨）

### 10.1 Function

- RSpec で `SELECT function(...)`
- 戻り値を必ず検証

### 10.2 Trigger

- 直接呼び出さない
- INSERT / UPDATE 後の副作用を検証

---

## 11. CI / レビュー必須

- `rails zeitwerk:check`
- SQL ファイル差分の確認
- trigger の `DROP → CREATE` を確認
- rollback 可能か確認

---

## 12. まとめ

本規約を遵守することで、

- DB ロジックの可視性向上
- Migration 事故の防止
- 長期保守性の確保
- チーム全体の生産性向上

を実現する。
