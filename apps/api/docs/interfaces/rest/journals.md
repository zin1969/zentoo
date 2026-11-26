# 仕訳一覧 API

認証済みユーザーの仕訳を、期間・キーワード・科目・タグを指定して一覧で取得する REST API

---

## Endpoint

```text
GET /journals
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- 認証済みユーザーの仕訳のみ返す
- 参照のみの API なので本文に `next_token` は含めない。新しいトークンはレスポンスヘッダ `X-Next-Token` で返す（画面を開いたままでも期限切れにならないよう、BFF が Cookie を更新する）

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
| q    | No       | キーワード。店舗名（収入・振替では摘要）か明細の品目に含まれる仕訳を返す（部分一致、大文字小文字を区別しない）。前後の空白は除き、`%` と `_` は文字として扱う。空なら絞らない |
| element_type | No | 科目の要素（1: 資産、2: 負債、3: 元入金、4: 収益、5: 費用）。`account_id` と組で指定する |
| account_id | No | 科目・口座・カードの ID。借方・貸方のどちらかでこの科目を使っている仕訳を返す。費用科目・収益科目は、親の科目を指定すると子科目の仕訳も含める（共通科目か本人の科目だけ）。`element_type` と組で指定する |
| tag_id | No     | タグの ID。このタグが付いた明細のある仕訳を返す |

- 条件はすべて AND で絞り込む。期間を省略すると全期間から探す
- 他人の科目・タグを指定しても、何も返さないだけ（存在しないものと区別しない）

## Response

### Success (200 OK)

日付の新しい順（同じ日付は ID の新しい順）に、1 ページ 50 件を返す。該当が無い、またはページが範囲外の場合、`journals` は空配列。`total_count` は条件に合う仕訳の数。明細は、条件に合わないものも含めて仕訳ごと返す。

```json
{
  "journals": [
    {
      "id": 15,
      "journal_date": "2026-10-27",
      "store_name": "フェザー・ステップ",
      "debits": [
        { "element_type": 2, "account_id": 3, "account_name": "tcard", "item_name": "革靴", "amount": 14000, "tax_rate": null, "tax_excluded_amount": null, "tags": [] }
      ],
      "credits": [
        { "element_type": 1, "payment_method_type": 2, "account_id": 2, "account_name": "三菱UFJ銀行 用賀出張所", "amount": 14000 }
      ],
      "original_journal_id": 14,
      "payment_date_overridden": false,
      "direct_debit_journal_id": null
    }
  ],
  "page": 1,
  "per_page": 50,
  "total_count": 1
}
```

- `account_name`: 科目の名前。科目を引けない場合は `null`
- `tags`（借方）: 明細に付いているタグ（`{ "id", "name" }` の配列。お買い物の費用の明細だけ。付いていなければ空配列）
- `original_journal_id`: この仕訳が引き落とし仕訳の場合、元のカード払い仕訳の ID。それ以外は `null`
- `payment_date_overridden`: 引き落とし仕訳の日付を手で変えた場合は `true`（[引き落とし日の変更 API](direct_debit_journals.md)）。引き落とし仕訳以外は `false`
- `direct_debit_journal_id`: この仕訳がカード払いの場合、引き落とし仕訳の ID。それ以外は `null`

### Validation Error (422 Unprocessable Entity)

```json
{
  "errors": ["To must not be earlier than from"]
}
```

- `element_type` と `account_id` の片方だけ、`element_type` が 1〜5 以外、ID が 1 以上の整数でない場合も 422

### Authorization Error (401 Unauthorized)

```json
{
  "error": "unauthorized"
}
```
