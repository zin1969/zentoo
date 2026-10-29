# 仕訳一覧 API

認証済みユーザーの仕訳を、期間を指定して一覧で取得する REST API

---

## Endpoint

```text
GET /journals
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- 認証済みユーザーの仕訳のみ返す
- 参照のみの API なので `next_token` は返却しない（トークンのローテーションは行わない）

## Request

### Headers
| Name          | Required | Description    |
| ------------- | -------- | -------------- |
| Authorization | Yes      | Bearer {token} |

### Query
| Name | Required | Description |
| ---- | -------- | ----------- |
| from | No       | 期間の開始日（`YYYY-MM-DD`、この日を含む）。省略すると開始日で絞らない |
| to   | No       | 期間の終了日（`YYYY-MM-DD`、この日を含む）。省略すると終了日で絞らない。`from` より前は指定できない |
| page | No       | ページ番号（1 始まりの整数）。省略すると 1 |

## Response

### Success (200 OK)

日付の新しい順（同じ日付は ID の新しい順）に、1 ページ 50 件を返す。該当が無い、またはページが範囲外の場合、`journals` は空配列。

```json
{
  "journals": [
    {
      "id": 15,
      "journal_date": "2026-10-27",
      "store_name": "フェザー・ステップ",
      "debits": [
        { "element_type": 2, "account_id": 3, "account_name": "tcard", "item_name": "革靴", "amount": 14000 }
      ],
      "credits": [
        { "element_type": 1, "payment_method_type": 2, "account_id": 2, "account_name": "三菱UFJ銀行 用賀出張所", "amount": 14000 }
      ],
      "original_journal_id": 14,
      "direct_debit_journal_id": null
    }
  ],
  "page": 1,
  "per_page": 50,
  "total_count": 1
}
```

- `account_name`: 科目の名前。科目を引けない場合は `null`
- `original_journal_id`: この仕訳が引き落とし仕訳の場合、元のカード払い仕訳の ID。それ以外は `null`
- `direct_debit_journal_id`: この仕訳がカード払いの場合、引き落とし仕訳の ID。それ以外は `null`

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
