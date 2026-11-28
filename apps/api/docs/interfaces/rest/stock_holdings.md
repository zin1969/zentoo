# 保有株 API

現物株の銘柄ごとに、基準日時点の株数・取得額・平均取得単価を返す REST API（M18）。

---

## Endpoint

```text
GET /stock-holdings?date=2026-11-30
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- 本人の銘柄だけを返す
- 参照のみの API なので本文に `next_token` は含めず、新しいトークンはレスポンスヘッダ `X-Next-Token` で返す

## Request

### Query
| Name | Required | Description |
| ---- | -------- | ----------- |
| date | No       | 基準日（`YYYY-MM-DD`。この日を含む）。省略すると今日（日本時間） |

## Response

### Success (200 OK)

```json
{
  "date": "2026-11-30",
  "holdings": [
    { "account_id": 21, "account_name": "トヨタ 7203", "shares": 150, "cost": 382537, "average_price": 2550.25 },
    { "account_id": 22, "account_name": "ソニー 6758", "shares": 0, "cost": 0, "average_price": null }
  ],
  "total_cost": 382537
}
```

- DB 関数 `get_stock_holdings`。銘柄は種別「投資」の口座のうち、基準日までに株数を持つ明細（開始残高・買い・売り）があるもの。口座の ID 順
- iDeCo・NISA のように株数を持たない投資の口座は含めない
- `shares`: 株数（借方の株数 − 貸方の株数）。全部売ると 0
- `cost`: 取得額（銘柄の口座の残高 = 借方 − 貸方。手数料を含む）
- `average_price`: 平均取得単価（`cost` ÷ `shares`、小数第 2 位まで四捨五入）。`shares` が 0 なら `null`
- `total_cost`: `cost` の合計

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
