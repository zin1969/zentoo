# 現金預け入れ仕訳 API

現金を預金口座に預け入れる仕訳（借方: 預金口座、貸方: 現金）を登録する REST API

---

## Endpoint

```text
POST /cash-deposit-journals
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- トークンはワンタイムであり、レスポンスごとに更新される
- 仕訳の持ち主は認証済みユーザーになる。リクエストに `user_id` を含めても無視される
- 預け入れ先は、認証済みユーザーの預金口座（`asset_type` が預金）のみ。現金・電子マネーの科目は指定できない
- 貸方の現金科目は、ユーザーの現金科目が 1 つだけのときに限って、それを使う

## Request

### Headers
| Name          | Required | Description             |
| ------------- | -------- | ----------------------- |
| Authorization | Yes      | Bearer {one-time-token} |
| Content-Type  | Yes      | application/json        |

### Body

```json
{
  "journal_date": "2026-10-20",
  "bank_account_id": 2,
  "amount": 45000
}
```

| Name            | Required | Description |
| --------------- | -------- | ----------- |
| journal_date    | Yes      | 預け入れた日（`YYYY-MM-DD`。過去・未来も指定できる） |
| bank_account_id | Yes      | 預け入れ先の預金口座の ID（`GET /asset-accounts` の `payment_method_type` が 2 のもの） |
| amount          | Yes      | 金額（1 以上の整数） |

## Response

### Success (201 Created)

登録された仕訳は、親仕訳の店名が預金口座の名前、借方の項目名が「預入」になる。

```json
{
  "journal_id": 456,
  "next_token": "abc.def.ghi"
}
```

### Validation Error (422 Unprocessable Entity)

```json
{
  "errors": ["Amount must be an integer between 1 and 2147483647"],
  "next_token": "abc.def.ghi"
}
```

### Cash Account Error (422 Unprocessable Entity)

ユーザーの現金科目が 0 件、または 2 件以上で、貸方の科目を決められない場合。

```json
{
  "error": "cash_account_not_determined",
  "next_token": "abc.def.ghi"
}
```

### Not Found (404 Not Found)

預け入れ先が、存在しない、他のユーザーの科目、または預金口座ではない場合。これらは区別しない。

```json
{
  "error": "asset_account_not_found",
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
- 内部で PostgreSQL 関数 `create_cash_deposit_journal` を呼び出す。仕訳は残高（`GET /account-balances`）にすぐ反映される
