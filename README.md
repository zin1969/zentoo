# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

# Rails 8 コーディング規約・推奨ディレクトリ構成（セキュリティ完成版）

本ドキュメントは、

* **Rails 8 アプリケーションにおけるコーディング規約**
* **セキュリティを考慮した推奨ディレクトリ構成**

を一体として定義するものである。

目的は以下の通りとする。

* セキュリティ脆弱性を構造で抑止する
* レビュー対象を明確化し、属人性を排除する
* DDD の考え方を取り入れつつ Rails との親和性を保つ

---

## 1. 基本方針

### 1.1 構造で守る

本規約では、

> **「人の注意」ではなく「コード構造」で事故を防ぐ**

ことを基本方針とする。

危険になりやすい処理は、専用ディレクトリに隔離し、
**置き場所そのものをレビュー判断基準**とする。

---

### 1.2 信頼境界（Trust Boundary）の明確化

以下の処理はアプリケーション内部と外部の信頼境界を越えるため、
**常にセキュリティレビュー対象**とする。

* データベースへの直接アクセス
* 外部通信（HTTP / Mail）
* OS・ファイルシステム操作
* 認証・セッション管理

---

## 2. 推奨ディレクトリ構成（完成版）

```text
app/
├── controllers/          # HTTP 入力受付（薄く保つ）
├── models/               # ActiveRecord（永続化専用）
├── services/             # ユースケース／オーケストレーション
│
├── forms/                # ユーザー入力受付・検証
├── values/               # Value Object（不変）
├── entities/             # ドメイン Entity（DB 非依存）
├── assemblers/           # 変換責務（form → entity 等）
│
├── repositories/         # ★ DB 境界（SQL）
├── gateways/             # ★ 外部通信境界（HTTP / Mail）
│   ├── http/             # HTTP API 通信
│   └── mail/             # メール送信（SMTP）
├── system_interfaces/    # ★ OS / FS 境界
├── session_handlers/     # ★ 認証・セッション境界
│
├── validators/           # 共通入力検証
├── presenters/           # View 用整形ロジック
└── support/              # 明確に命名された共通処理のみ
```

★：**常にセキュリティレビュー対象**

---

## 3. レイヤー別コーディング規約

### 3.1 controllers

#### 責務

* パラメータ受け渡し
* Service 呼び出し
* レスポンス生成

#### 禁止事項

* 生 SQL
* 外部通信
* OS / ファイル操作

---

### 3.2 models（ActiveRecord）

#### 責務

* 永続化
* バリデーション（DB 整合性レベル）

#### ルール

* ドメインロジックを肥大化させない
* 複雑なクエリは Repository に委譲する

---

### 3.3 services

#### 責務

* ユースケース単位の処理
* 各レイヤーの調停

#### ルール

* 危険 API を直接使用しない
* Entity / Repository / Gateway を組み合わせる

---

### 3.4 forms

#### 責務

* ユーザー入力の受付
* 型・必須・形式チェック

#### ルール

* ActiveModel::Model を使用
* DB・外部通信を行わない

---

### 3.5 values

#### 責務

* 値の厳密な表現

#### ルール

* 不変（immutable）
* 状態を持たない
* DB と直接対応しない

---

### 3.6 entities

#### 責務

* ドメインロジック

#### ルール

* ActiveRecord を継承しない
* 永続化の責務を持たない

---

### 3.7 assemblers

#### 責務

* データ変換

例：

* Form → Entity
* Entity → DTO

---

## 4. セキュリティ境界レイヤー規約

### 4.1 repositories（DB 境界）

#### 主な脅威

* SQL インジェクション

#### 必須ルール

* プレースホルダ使用
* 文字列連結による SQL 生成禁止

---

### 4.2 gateways（外部通信境界）

#### ディレクトリ構成ルール

```
app/gateways/
├── http/   # HTTP / REST / Web API 通信
└── mail/   # メール送信（SMTP）
```

* HTTP 通信とメール送信は必ず分離する
* `gateways` 直下にクラスを置かない

#### 主な脅威

* ヘッダインジェクション

#### 必須ルール

* ヘッダにユーザー入力を直接設定しない

---

### 4.3 system_interfaces（OS / FS 境界）

#### 主な脅威

* OS コマンドインジェクション
* ディレクトリトラバーサル

#### 必須ルール

* コマンドは配列引数のみ
* パスはホワイトリスト検証

---

### 4.4 session_handlers（認証・セッション境界）

#### 主な脅威

* セッション固定
* 不適切な失効管理

---

## 5. 共通禁止事項

* Controller / Model での system / exec / `` の使用
* View での SQL・外部通信
* utils 的な責務不明コードの追加

---

## 6. セキュリティレビュー運用

### 6.1 必須レビュー対象

```text
app/repositories/**
app/gateways/**
app/system_interfaces/**
app/session_handlers/**
```

### 6.2 レビュー観点（抜粋）

* 信頼境界を越える入力が検証されているか
* 共通安全 API を使用しているか

---

## 7. まとめ

本規約・構成は、

* Rails の開発効率を損なわず
* セキュリティと監査対応力を高め
* 長期運用に耐える

ことを目的とした **実務向け完成形** である。

---

## 8. 改訂履歴

| 日付         | 内容   | 担当 |
| ---------- | ---- | -- |
| YYYY-MM-DD | 初版作成 |    |

---

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

| 種別        | メソッド                                 |
| --------- | ------------------------------------ |
| Function  | `create_function`, `drop_function`   |
| Procedure | `create_procedure`, `drop_procedure` |
| Trigger   | `create_trigger`, `drop_trigger`     |

### 7.2 `execute_sql` の直接利用

- 原則禁止
- 新種別 DB オブジェクト対応など、やむを得ない場合のみ可

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

---
