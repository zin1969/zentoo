# 口座・カード・費用科目の管理 API

口座（現金・預金・電子マネー）、クレジットカード、費用科目を追加・変更・削除する REST API。一覧の取得は [勘定科目マスタ API](accounts.md) と、下の `GET /credit-cards`

---

## Endpoint

```text
POST   /asset-accounts
PUT    /asset-accounts/{id}
DELETE /asset-accounts/{id}

GET    /credit-cards
POST   /credit-cards
PUT    /credit-cards/{id}
DELETE /credit-cards/{id}

POST   /expense-accounts
PUT    /expense-accounts/{id}
DELETE /expense-accounts/{id}

POST   /revenue-accounts
PUT    /revenue-accounts/{id}
DELETE /revenue-accounts/{id}
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- 口座・カードは、認証済みユーザーのものだけ扱える。他ユーザーのものは、存在しないものと同じ 404 を返す
- 費用科目は、全ユーザー共通の科目（`user_id` が NULL）と認証済みユーザー自身の科目を扱える。追加する科目は共通科目になる
- 追加・変更は、本文に新しい `next_token` を返す（エラー時も、401 を除いて返す）
- 削除は成功時に本文を返さない（204）。新しいトークンはレスポンスヘッダ `X-Next-Token` で返す
- `GET /credit-cards` は配列を返すため、新しいトークンはレスポンスヘッダ `X-Next-Token` で返す

## 共通のルール
- 仕訳で使われている科目は、名前（とカードの締め日・支払日・引き落とし口座）だけ変えられる。削除と種別・親の変更は、使われていない科目だけ。仕訳の明細は科目を ID で参照していて外部キーが無いため、消すと仕訳の一覧に「不明な科目」が出て、月次の支出から抜けてしまう
- 一覧の `in_use` が true の科目が、使われている科目
- 名前は前後の空白を取り除き、50 文字まで。同じ名前は作れない（口座・カードは本人の中で、費用科目は同じ親の中で）

## 口座

### Body（POST / PUT）

```json
{
  "name": "みずほ銀行 玉川支店",
  "asset_type": 2
}
```

| Name       | Required | Description |
| ---------- | -------- | ----------- |
| name       | Yes      | 口座の名前 |
| asset_type | Yes      | 1 = 現金, 2 = 預貯金, 3 = 電子マネー（一覧の `payment_method_type` と同じ値） |

- 現金の口座は 1 つだけ（現金の預け入れが、現金の口座が 1 つに決まることを前提にしているため）
- 次の口座は「使われている」扱いで、削除と種別の変更ができない: 仕訳で使われている口座、カードの引き落とし口座になっている預金口座
- 開始残高は [開始資産登録 API](asset_opening_journals.md) で登録する

## クレジットカード

カードは、負債科目（クレジットカード払い）と引き落とし設定（締め日・支払日・引き落とし口座）の組で、いつも一緒に登録・変更・削除する。`id` は負債科目の ID（お買い物登録の支払い方法の `account_id` と同じ）。

### `GET /credit-cards`

```json
[
  {
    "id": 3,
    "name": "tcard",
    "cutoff_day": 10,
    "payment_day": 27,
    "bank_account_id": 2,
    "bank_account_name": "三菱UFJ銀行 用賀出張所",
    "in_use": true
  }
]
```

- 負債科目のうち、クレジットカード払いだけを返す（借入金・キャッシングは返さない）
- 引き落とし設定の無いカードは、`cutoff_day` などを null にして返す。設定が無いままカードで払うと `credit_card_setting_not_found` になるので、変更から登録する

### Body（POST / PUT）

```json
{
  "name": "JAL",
  "cutoff_day": 15,
  "payment_day": 10,
  "bank_account_id": 2
}
```

| Name            | Required | Description |
| --------------- | -------- | ----------- |
| name            | Yes      | カードの名前。本人の負債科目の中で重ならないこと |
| cutoff_day      | Yes      | 締め日（1〜31）。月に無い日は月末として扱う |
| payment_day     | Yes      | 支払日（1〜31）。月に無い日は月末として扱い、土日・祝日は翌営業日にずらす |
| bank_account_id | Yes      | 引き落とし口座。本人の預金口座だけ |

- 締め日・支払日・引き落とし口座を変えても、登録済みの引き落とし仕訳は変えない（新しい設定は、これから登録するカード払いから使う。日付は [引き落とし日の変更 API](direct_debit_journals.md) で個別に直せる）
- 変更のとき引き落とし設定が無ければ作る
- 未払いの残高は [開始負債登録 API](liability_opening_journals.md) で登録する

## 費用科目・収益科目

収益科目（`/revenue-accounts`）は、費用科目と同じルール・同じ本文で扱う。エラーコードの頭だけが違う（`expense_account_*` / `revenue_account_*`）。

### Body（POST / PUT）

```json
{
  "name": "食材",
  "parent_id": 1
}
```

| Name      | Required | Description |
| --------- | -------- | ----------- |
| name      | Yes      | 科目の名前。同じ親の中で重ならないこと |
| parent_id | No       | 親の科目の ID。省略または null でトップレベルの科目になる |

- 親子の 2 階層。親にできるのは、親の無い科目だけ（自分自身は除く）
- 使われているかは、共通科目なので全ユーザーの仕訳で判定する（費用科目は借方、収益科目は貸方）
- 子科目のある科目は、削除できず、親も設定できない（3 階層にしないため）

## Response

### Success
| API | Status | Body |
| --- | ------ | ---- |
| `POST` | 201 Created | `{ "id": 7, "next_token": "..." }` |
| `PUT` | 200 OK | `{ "id": 7, "next_token": "..." }` |
| `DELETE` | 204 No Content | なし |

### Errors
| Status | error / errors | 内容 |
| ------ | -------------- | ---- |
| 404 | `asset_account_not_found` | 口座が存在しない、または他ユーザーの口座 |
| 404 | `credit_card_not_found` | カードが存在しない、他ユーザーのカード、またはクレジットカードではない負債科目 |
| 404 | `bank_account_not_found` | 引き落とし口座が、本人の預金口座ではない |
| 404 | `expense_account_not_found` / `revenue_account_not_found` | 費用科目・収益科目が存在しない、または他ユーザーの科目 |
| 422 | `errors` | 本文のバリデーションエラー |
| 422 | `duplicate_account_name` | 同じ名前の科目がある |
| 422 | `cash_account_already_exists` | 現金の口座はすでにある |
| 422 | `asset_account_in_use` | 使われている口座の削除・種別の変更 |
| 422 | `credit_card_in_use` | 使われているカードの削除 |
| 422 | `expense_account_in_use` / `revenue_account_in_use` | 使われている科目の削除・親の付け替え |
| 422 | `expense_account_has_children` / `revenue_account_has_children` | 子科目のある科目の削除・親の設定 |
| 422 | `invalid_parent` | 親が存在しない、子科目、または自分自身 |

```json
{
  "error": "asset_account_in_use",
  "next_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

### Authorization Error (401 Unauthorized)

```json
{
  "error": "unauthorized"
}
```
