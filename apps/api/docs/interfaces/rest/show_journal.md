# 仕訳取得（1 件）API

認証済みユーザーの仕訳を 1 件取得する REST API。修正画面の初期値に使う

---

## Endpoint

```text
GET /journals/{id}
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- 認証済みユーザーの仕訳のみ返す。他ユーザーの仕訳は、存在しない仕訳と同じ 404 を返す
- 参照のみの API なので本文に `next_token` は含めない。新しいトークンはレスポンスヘッダ `X-Next-Token` で返す

## Request

### Headers
| Name          | Required | Description    |
| ------------- | -------- | -------------- |
| Authorization | Yes      | Bearer {token} |

### Path
| Name | Required | Description |
| ---- | -------- | ----------- |
| id   | Yes      | 仕訳の ID（1 以上の整数） |

## Response

### Success (200 OK)

形は [仕訳一覧 API](journals.md) の `journals` の 1 件と同じ。

```json
{
  "id": 14,
  "journal_date": "2026-10-20",
  "store_name": "Aquavit 001",
  "debits": [
    { "element_type": 5, "account_id": 7, "account_name": "外食", "asset_type": null, "item_name": "バー", "amount": 3300, "tax_rate": 10, "tax_excluded_amount": 3000, "shares": null, "tags": [] }
  ],
  "credits": [
    { "element_type": 2, "payment_method_type": 3, "account_id": 3, "account_name": "tcard", "amount": 3300, "shares": null }
  ],
  "original_journal_id": null,
  "direct_debit_journal_id": 15
}
```

- 借方の `tax_rate` / `tax_excluded_amount`: 外税のレシートで登録した明細の税率（%）と税抜の金額。内税の明細は `null`。消費税は `amount - tax_excluded_amount`
- `asset_type`（借方）: 資産の明細の口座の種別（6 = 立替金など）。資産以外の明細は `null`
- `shares`: 株の銘柄の株数（借方は開始残高・買い、貸方は売り。[株の売買 API](stock_trades.md)）。それ以外の明細は `null`

### Not Found (404 Not Found)

```json
{
  "error": "journal_not_found"
}
```

### Authorization Error (401 Unauthorized)

```json
{
  "error": "unauthorized"
}
```
