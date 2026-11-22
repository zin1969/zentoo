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

支出（`total`・`items`）と収入（`income_total`・`income_items`）を、それぞれ金額の大きい順（同額は科目 ID の昇順）に返す。`net` は収支（収入 − 支出）。該当が無い月は合計が 0、一覧が空配列。

```json
{
  "month": "2026-10",
  "total": 4000,
  "items": [
    { "account_id": 2, "account_name": "交通費", "amount": 3000 },
    { "account_id": 1, "account_name": "食費", "amount": 1000 }
  ],
  "income_total": 300000,
  "income_items": [
    { "account_id": 1, "account_name": "給与", "amount": 300000 }
  ],
  "net": 296000
}
```

| Name | Description |
| ---- | ----------- |
| `total` / `items` | 支出の合計 / 費用科目ごとの支出（以前からの項目名のまま） |
| `income_total` / `income_items` | 収入の合計 / 収益科目ごとの収入 |
| `net` | 収支（収入 − 支出）。マイナスは赤字 |

- 集計するのは、仕訳日が対象月の仕訳にある、費用科目の借方
- カード払いは、買い物をした日の月に計上する（引き落とし仕訳は費用ではないので集計に含めない）
- 科目は登録された科目そのままで集計する（親の科目へのまとめ上げはしない）
- 収入は、仕訳日が対象月の仕訳にある、収益科目の貸方を集計する（[収入の登録 API](income_journals.md)）
- 計算は PostgreSQL 関数 `get_monthly_expenses`（支出）と `get_monthly_incomes`（収入）が行う

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
