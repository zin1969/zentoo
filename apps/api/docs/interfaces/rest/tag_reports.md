# タグの集計 API

タグ（目的）ごとの支出を、年の月ごとに集計し、月の明細を取得する REST API

---

## Endpoint

```text
GET /tag-reports/{id}
GET /tag-reports/{id}/items
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- 認証済みユーザーのタグだけ集計できる。他ユーザーのタグは、存在しないタグと同じ 404 を返す
- 参照のみの API なので本文に `next_token` は含めない。新しいトークンはレスポンスヘッダ `X-Next-Token` で返す

## Request

### Path
| Name | Required | Description |
| ---- | -------- | ----------- |
| id   | Yes      | タグの ID |

### Query
| API | Name | Required | Description |
| --- | ---- | -------- | ----------- |
| `GET /tag-reports/{id}` | year | No | 対象の年（`YYYY`、2000〜2100）。省略すると今年（日本時間） |
| `GET /tag-reports/{id}/items` | month | No | 対象月（`YYYY-MM`）。省略すると今月（日本時間） |

## 集計の仕方
- 集計するのは、そのタグが付いた費用の明細（お買い物の明細）
- 日付は仕訳日（買った日）で数える。カード払いも買った日の月に入る
- 1 つの明細に複数のタグを付けた場合は、それぞれのタグで数える。そのため、タグごとの合計を足しても、支出の合計とは合わない
- 計算は PostgreSQL 関数 `get_tag_monthly_totals`（月ごとの合計）と `get_tag_items`（明細）が行う

## Response

### `GET /tag-reports/{id}`（200 OK）

1〜12 月の 12 件を返す。明細の無い月は 0。

```json
{
  "tag": { "id": 3, "name": "勉強" },
  "year": 2026,
  "total": 6000,
  "months": [
    { "month": 1, "amount": 3000 },
    { "month": 2, "amount": 0 },
    { "month": 3, "amount": 3000 }
  ]
}
```

（`months` は 12 月まで続く）

### `GET /tag-reports/{id}/items`（200 OK）

仕訳日・明細の順に返す。該当が無い月は `total` が 0、`items` が空配列。

```json
{
  "tag": { "id": 3, "name": "勉強" },
  "month": "2026-01",
  "total": 3000,
  "items": [
    {
      "journal_id": 21, "journal_date": "2026-01-10", "store_name": "本屋",
      "item_name": "参考書", "account_id": 7, "account_name": "書籍", "amount": 2000
    },
    {
      "journal_id": 24, "journal_date": "2026-01-25", "store_name": "本屋",
      "item_name": "Rails 勉強会", "account_id": 9, "account_name": "セミナー", "amount": 1000
    }
  ]
}
```

### Errors
| Status | error / errors | 内容 |
| ------ | -------------- | ---- |
| 404 | `tag_not_found` | タグが存在しない、または他ユーザーのタグ |
| 422 | `errors` | 年・月の指定が不正 |

### Authorization Error (401 Unauthorized)

```json
{
  "error": "unauthorized"
}
```
