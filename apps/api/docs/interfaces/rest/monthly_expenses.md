# 月次支出 API

指定した月の、認証済みユーザーの費用（支出）を科目ごとに集計して取得する REST API

---

## Endpoint

```text
GET /monthly-expenses
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- 認証済みユーザーの仕訳のみが対象
- 参照のみの API なので本文に `next_token` は含めない。新しいトークンはレスポンスヘッダ `X-Next-Token` で返す（画面を開いたままでも期限切れにならないよう、BFF が Cookie を更新する）

## Request

### Headers
| Name          | Required | Description    |
| ------------- | -------- | -------------- |
| Authorization | Yes      | Bearer {token} |

### Query
| Name  | Required | Description |
| ----- | -------- | ----------- |
| month | No       | 対象月（`YYYY-MM`）。省略すると今月（日本時間） |

## Response

### Success (200 OK)

金額の大きい順（同額は科目 ID の昇順）に返す。該当が無い月は `total` が 0、`items` が空配列。

```json
{
  "month": "2026-10",
  "total": 4000,
  "items": [
    { "account_id": 2, "account_name": "交通費", "amount": 3000 },
    { "account_id": 1, "account_name": "食費", "amount": 1000 }
  ]
}
```

- 集計するのは、仕訳日が対象月の仕訳にある、費用科目の借方
- カード払いは、買い物をした日の月に計上する（引き落とし仕訳は費用ではないので集計に含めない）
- 科目は登録された科目そのままで集計する（親の科目へのまとめ上げはしない）
- 計算は PostgreSQL 関数 `get_monthly_expenses` が行う

### Validation Error (422 Unprocessable Entity)

```json
{
  "errors": ["Month must be a month (YYYY-MM)"]
}
```

### Authorization Error (401 Unauthorized)

```json
{
  "error": "unauthorized"
}
```
