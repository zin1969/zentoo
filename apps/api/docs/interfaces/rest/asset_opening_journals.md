# 開始資産仕訳 API

開始資産を登録するための REST API

---

## Endpoint

```text
POST /asset-opening-journals
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- トークンはワンタイムであり、レスポンスごとに更新される

## Request

### Headers
| Name          | Required | Description             |
| ------------- | -------- | ----------------------- |
| Authorization | Yes      | Bearer {one-time-token} |
| Content-Type  | Yes      | application/json        |

### Body

```json
{
  "journal_date": "2026-02-01",
  "asset_type": 1,
  "asset_account_id": 123,
  "amount": 100000
}
```

| Name             | Required | Description |
| ---------------- | -------- | ----------- |
| journal_date     | Yes      | 日付（`YYYY-MM-DD`） |
| asset_type       | Yes      | 要素種別（1 = 資産） |
| asset_account_id | Yes      | 資産の口座の ID |
| amount           | Yes      | 金額。株の銘柄のときは 株数 × 平均取得単価（円未満は画面で四捨五入） |
| shares           | No       | 株数（1 〜 2147483647）。株の銘柄（種別「投資」の口座）の開始残高のときだけ渡す |

### 株の銘柄の開始残高（`shares` あり）

今持っている株を、株数と平均取得単価で登録する（M18）。

```json
{
  "journal_date": "2026-11-01",
  "asset_type": 1,
  "asset_account_id": 21,
  "amount": 250050,
  "shares": 100
}
```

- DB 関数 `create_opening_stock_balance_journal`。開始資産と同じ仕訳（借方: 銘柄、貸方: 元入金）を作り、借方の明細に株数を持たせる
- 株数を持てるのは種別「投資」の口座だけ。iDeCo・NISA のように株数を持たないものは `shares` を省略する
- その銘柄に、登録する日より後の日付の売りがあると登録できない（[株の売買 API](stock_trades.md)）
- 銘柄ごとの株数・取得額は [保有株 API](stock_holdings.md) で見る

## Response

### Success (201 Created)

```json
{
  "journal_id": 456,
  "next_token": "abc.def.ghi"
}
```

### Validation Error (422 Unprocessable Entity)

```json
{
  "errors": {
    "asset_type": ["must be an ElementType"]
  },
  "next_token": "abc.def.ghi"
}
```

### Authorization Error (401 Unauthorized)

```json
{
  "error": "unauthorized"
}
```

### Not Found (404 Not Found)

指定した勘定科目が存在しない、または認証済みユーザーの科目ではない場合。両者は区別しない。

```json
{
  "error": "asset_account_not_found",
  "next_token": "abc.def.ghi"
}
```

### Business Error (422 Unprocessable Entity)

| error | 内容 |
| ----- | ---- |
| `shares_require_investment_account` | 株数を渡したが、種別「投資」の口座ではない |
| `later_sale_exists` | 株数を渡したが、その銘柄に後の日付の売りがある |

### Business Error (409 Conflict:重複)

```json
{
  "error": "opening_asset_already_exists",
  "next_token": "abc.def.ghi"
}
```

## Notes

- 成功・バリデーションエラー・業務エラーの場合、`next_token` を返却する
- 認可エラー（401）の場合、`next_token` は返却しない
