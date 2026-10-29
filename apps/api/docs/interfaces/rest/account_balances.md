# 残高 API

指定日時点の、認証済みユーザーの資産・負債科目ごとの残高を取得する REST API

---

## Endpoint

```text
GET /account-balances
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- 認証済みユーザーの資産・負債科目と仕訳のみが対象
- 参照のみの API なので本文に `next_token` は含めない。新しいトークンはレスポンスヘッダ `X-Next-Token` で返す（画面を開いたままでも期限切れにならないよう、BFF が Cookie を更新する）

## Request

### Headers
| Name          | Required | Description    |
| ------------- | -------- | -------------- |
| Authorization | Yes      | Bearer {token} |

### Query
| Name | Required | Description |
| ---- | -------- | ----------- |
| date | No       | 基準日（`YYYY-MM-DD`、この日の仕訳まで含める）。省略すると今日（日本時間） |

## Response

### Success (200 OK)

仕訳が 1 件も無い科目も、残高 0 で返す。科目は ID の昇順。

```json
{
  "date": "2026-10-31",
  "assets": [
    { "account_id": 1, "account_name": "現金", "balance": 99000 },
    { "account_id": 2, "account_name": "三菱UFJ銀行 用賀出張所", "balance": 500000 }
  ],
  "liabilities": [
    { "account_id": 3, "account_name": "tcard", "balance": 14000 }
  ],
  "total_assets": 599000,
  "total_liabilities": 14000,
  "net_assets": 585000
}
```

- 資産の `balance`: 借方の合計 − 貸方の合計
- 負債の `balance`: 貸方の合計 − 借方の合計（未払いの額）
- `net_assets`: `total_assets` − `total_liabilities`
- カード払いは、引き落とし日までは負債として残り、引き落とし日（基準日がその日以降）に負債が減って銀行口座の残高も減る。基準日より後の仕訳は含めない
- 計算は PostgreSQL 関数 `get_account_balances` が行う

### Validation Error (422 Unprocessable Entity)

```json
{
  "errors": ["Date must be a date (YYYY-MM-DD)"]
}
```

### Authorization Error (401 Unauthorized)

```json
{
  "error": "unauthorized"
}
```
