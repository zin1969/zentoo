# 開始負債仕訳 API

開始時点で未払いのクレジットカードの残高を登録するための REST API

---

## Endpoint

```text
POST /liability-opening-journals
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- トークンはワンタイムであり、レスポンスごとに更新される
- 仕訳の持ち主は認証済みユーザーになる。リクエストに `user_id` を含めても無視される
- 対象は、認証済みユーザーのクレジットカード（`liability_type` がクレジットカードの負債科目）のみ

## Request

### Headers
| Name          | Required | Description             |
| ------------- | -------- | ----------------------- |
| Authorization | Yes      | Bearer {one-time-token} |
| Content-Type  | Yes      | application/json        |

### Body

```json
{
  "journal_date": "2026-10-30",
  "liability_account_id": 3,
  "amount": 30000,
  "payment_date": "2026-11-10"
}
```

| Name                 | Required | Description |
| -------------------- | -------- | ----------- |
| journal_date         | Yes      | 開始日（`YYYY-MM-DD`。開始資産の登録と同じ日にそろえる） |
| liability_account_id | Yes      | カード（負債科目）の ID（`GET /liability-accounts`） |
| amount               | Yes      | 未払いの金額（1 以上の整数） |
| payment_date         | Yes      | 引き落とし日（`YYYY-MM-DD`。カードの明細にある支払日。開始日以降） |

## Response

### Success (201 Created)

次の 2 つの仕訳が作られる。

- 開始負債の仕訳（開始日）: 借方が元入金（項目名「開始残高」）、貸方がカード
- 引き落とし仕訳（引き落とし日）: 借方がカード、貸方がカードの引き落とし口座。カード払いと同じ仕組みで自動的に作られるが、日付は締日・支払日から計算せず、指定した引き落とし日をそのまま使う（土日・祝日でもずらさない）

```json
{
  "journal_id": 456,
  "next_token": "abc.def.ghi"
}
```

`journal_id` は、開始負債の仕訳の ID。

### Validation Error (422 Unprocessable Entity)

```json
{
  "errors": ["Amount must be an integer between 1 and 2147483647"],
  "next_token": "abc.def.ghi"
}
```

### Payment Date Error (422 Unprocessable Entity)

引き落とし日が開始日より前の場合（すでに支払い済みで、未払いではない）。

```json
{
  "error": "payment_date_before_journal_date",
  "next_token": "abc.def.ghi"
}
```

### Card Setting Error (422 Unprocessable Entity)

カードに引き落とし設定（締日・支払日・引き落とし口座）が無い場合。

```json
{
  "error": "credit_card_setting_not_found",
  "next_token": "abc.def.ghi"
}
```

### Not Found (404 Not Found)

指定したカードが、存在しない、他のユーザーの科目、またはクレジットカードではない場合。これらは区別しない。

```json
{
  "error": "liability_account_not_found",
  "next_token": "abc.def.ghi"
}
```

### Business Error (409 Conflict:重複)

同じカード・同じ引き落とし日の開始負債が、すでに登録されている場合。引き落とし日が違えば、同じカードでも登録できる。

```json
{
  "error": "opening_liability_already_exists",
  "next_token": "abc.def.ghi"
}
```

### Authorization Error (401 Unauthorized)

```json
{
  "error": "unauthorized"
}
```

## Notes

- 成功・バリデーションエラー・業務エラーの場合、`next_token` を返却する
- 認可エラー（401）の場合、`next_token` は返却しない
- 内部で PostgreSQL 関数 `create_opening_liability_balance_journal` を呼び出す
- 登録した未払いは、残高（`GET /account-balances`）で引き落とし日の前日まで負債として残り、引き落とし日に負債が減って銀行口座の残高も減る
