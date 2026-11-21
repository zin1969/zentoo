# 通帳 API

認証済みユーザーの預金口座の出入金を、銀行の通帳のように日付順で取得する REST API。未来の引き落とし予定も含む

---

## Endpoint

```text
GET /bank-account-ledgers/{id}
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- 認証済みユーザーの預金口座だけ見られる。他ユーザーの口座と、預金ではない口座（現金・電子マネー）は、存在しない口座と同じ 404 を返す
- 参照のみの API なので本文に `next_token` は含めない。新しいトークンはレスポンスヘッダ `X-Next-Token` で返す

## Request

### Headers
| Name          | Required | Description    |
| ------------- | -------- | -------------- |
| Authorization | Yes      | Bearer {token} |

### Path
| Name | Required | Description |
| ---- | -------- | ----------- |
| id   | Yes      | 預金口座の ID |

### Query
| Name | Required | Description |
| ---- | -------- | ----------- |
| from | No       | 期間の開始日（`YYYY-MM-DD`、この日を含む）。省略すると先月の初め（日本時間） |
| to   | No       | 期間の終了日（`YYYY-MM-DD`、この日を含む）。省略すると、口座の最後の予定日。それが今月末より前なら今月末。`from` より前は指定できない |

## 行の作り方
- DB 関数 `get_bank_account_ledger` が作る
- 1 行目は繰越（期間の初日の前日までの残高）。各行の `balance` は、繰越から 1 行ずつ積み上げた残高
- 行は日付順、同じ日は仕訳の登録順
- 1 行は 1 つの仕訳。ただし、カードの引き落としは、同じ日・同じカードの分を 1 行にまとめる（本物の通帳と同じ）。`items` に元のお買い物の内訳を付ける。内訳の金額は、そのお買い物のうちカードで払った額
- 引き落とし日は、引き落とし仕訳の日付（[引き落とし日の変更 API](direct_debit_journals.md) で手で変えた日を含む）
- 今日（日本時間）より後の行は `scheduled` が true（まだ引き落とされていない予定）
- `balance` がマイナスの行は、残高が足りない

## Response

### Success (200 OK)

```json
{
  "account": { "id": 2, "name": "三菱UFJ銀行 用賀出張所" },
  "from": "2026-10-01",
  "to": "2026-10-31",
  "today": "2026-10-20",
  "entries": [
    {
      "row_type": "carried_over", "date": "2026-09-30", "description": "繰越",
      "deposit": 0, "withdrawal": 0, "balance": 0, "scheduled": false,
      "card_account_id": null, "journal_ids": [], "items": []
    },
    {
      "row_type": "journal", "date": "2026-10-01", "description": "開始残高",
      "deposit": 10000, "withdrawal": 0, "balance": 10000, "scheduled": false,
      "card_account_id": null, "journal_ids": [21], "items": []
    },
    {
      "row_type": "card_payment", "date": "2026-10-27", "description": "tcard",
      "deposit": 0, "withdrawal": 5000, "balance": 5000, "scheduled": true,
      "card_account_id": 3, "journal_ids": [22, 24],
      "items": [
        { "journal_id": 22, "journal_date": "2026-10-05", "store_name": "スーパー", "amount": 3000 },
        { "journal_id": 24, "journal_date": "2026-10-08", "store_name": "八百屋", "amount": 2000 }
      ]
    }
  ]
}
```

| Name | Description |
| ---- | ----------- |
| `row_type` | `carried_over`（繰越）、`journal`（1 つの仕訳）、`card_payment`（同じ日・同じカードの引き落としのまとめ） |
| `description` | 摘要。仕訳は明細の項目名（開始残高・預入など）か店舗名、カードの行はカードの名前 |
| `deposit` / `withdrawal` | 入金 / 出金 |
| `balance` | この行のあとの残高 |
| `scheduled` | 今日より後の予定 |
| `card_account_id` | カードの行の、カード（負債科目）の ID。それ以外は `null` |
| `journal_ids` | カードの行は元のお買い物の仕訳、仕訳の行はその仕訳、繰越は空 |
| `items` | カードの行の、元のお買い物の内訳。それ以外は空 |

### Not Found (404 Not Found)

```json
{
  "error": "asset_account_not_found"
}
```

### Validation Error (422 Unprocessable Entity)

```json
{
  "errors": ["To must not be earlier than from"]
}
```

### Authorization Error (401 Unauthorized)

```json
{
  "error": "unauthorized"
}
```
