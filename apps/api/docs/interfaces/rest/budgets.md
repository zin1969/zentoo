# 予算 API

費用科目かタグごとに、週・月・年の予算を決め、期間ごとに使った額と比べる REST API（M20）。

---

## Endpoint

```text
GET    /budgets
POST   /budgets
PUT    /budgets/{id}
DELETE /budgets/{id}
GET    /budget-reports?date=2026-11-26
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- 予算はユーザーごと。本文に `user_id` を送っても無視する
- 費用科目は共通か本人の科目、タグは本人のタグだけ使える。それ以外は存在しないものと同じ 404 を返す
- 参照（`GET`）と削除の成功時は、新しいトークンをレスポンスヘッダ `X-Next-Token` で返す。追加・変更とエラーは本文の `next_token`

## 予算の形

| 項目 | 内容 |
| ---- | ---- |
| 対象 `target_type` | 1 = 費用科目（`expense_account_id`。親の科目なら子科目も含む）、2 = タグ（`tag_id`） |
| 除くタグ `excluded_tag_ids` | 費用科目の予算だけ。このタグが付いた明細は数えない（例: 食費からアルコールを外す） |
| 周期 `period_type` | 1 = 週（月曜〜日曜）、2 = 月、3 = 年（1 月〜12 月） |
| 額 `amount` | 1 回の期間の額 |
| 月ごとの額 `monthly_amounts` | 月の予算だけ。1〜12 月の 12 個の額。毎年くり返す（電気代・ガス代など）。送ると `amount` は使わず 0 で保存する |

- 繰り越しはしない（余った分を次の期間に回さない）
- 額の履歴は持たない。額を変えると、過去の期間も今の額で比べる
- 予算の対象の費用科目は削除できない（[口座・科目の管理](account_management.md)の `in_use` が true になる）。対象のタグも削除できない（[タグ API](tags.md) の `tag_used_by_budget`）。除くタグは、タグを削除すると外れる

## `GET /budgets`（200 OK）

周期の順（週・月・年）、同じ周期は作った順。

```json
[
  {
    "id": 1,
    "name": "食費",
    "target_type": 1,
    "expense_account_id": 3,
    "tag_id": null,
    "target_name": "食費",
    "period_type": 1,
    "amount": 7000,
    "monthly_amounts": null,
    "excluded_tags": [{ "id": 5, "name": "アルコール" }]
  }
]
```

## `POST /budgets`（201 Created）・`PUT /budgets/{id}`（200 OK）

```json
{
  "name": "電気代",
  "target_type": 1,
  "expense_account_id": 12,
  "period_type": 2,
  "monthly_amounts": [12000, 11000, 9000, 7000, 6000, 6000, 9000, 10000, 8000, 6000, 8000, 11000],
  "excluded_tag_ids": []
}
```

| Name               | Required | Description |
| ------------------ | -------- | ----------- |
| name               | Yes      | 名前（30 文字まで。前後の空白は取り除く） |
| target_type        | Yes      | 1 = 費用科目、2 = タグ |
| expense_account_id | 費用科目のとき | 費用科目の ID（タグのときは無視する） |
| tag_id             | タグのとき | タグの ID（費用科目のときは無視する） |
| period_type        | Yes      | 1 = 週、2 = 月、3 = 年 |
| amount             | `monthly_amounts` が無いとき | 1 回の期間の額（0 〜 2147483647） |
| monthly_amounts    | No       | 月の予算だけ。1〜12 月の 12 個の額（0 〜 2147483647） |
| excluded_tag_ids   | No       | 費用科目の予算から外すタグの ID（10 個まで）。変更では送った内容に置き換える |

本文は `{ "id": 1, "next_token": "..." }`。

## `DELETE /budgets/{id}`（204 No Content）

本文なし。仕訳は変わらない。

## `GET /budget-reports`（200 OK）

予算ごとに、基準日（`date`。省略すると今日）を含む期間の予算額・使った額・残りを返す。DB 関数 `get_budget_report`。

```json
{
  "date": "2026-11-26",
  "budgets": [
    {
      "id": 1, "name": "食費", "target_type": 1, "expense_account_id": 3, "tag_id": null, "target_name": "食費",
      "period_type": 1, "amount": 7000, "monthly_amounts": null, "excluded_tags": [{ "id": 5, "name": "アルコール" }],
      "period_start": "2026-11-23",
      "period_end": "2026-11-29",
      "budget_amount": 7000,
      "used_amount": 4200,
      "remaining_amount": 2800
    }
  ]
}
```

- `used_amount`: 期間の中の日付（買った日。カードの引き落とし日ではない）の、費用の明細の合計。費用科目は子科目も含み、除くタグの付いた明細は数えない。タグはそのタグが付いた費用の明細。立替金の明細は費用ではないので入らない（精算で足りなかった分は費用なので入る）
- `budget_amount`: その期間の額。月ごとに決めた額なら、その月の額
- `remaining_amount`: `budget_amount - used_amount`（使いすぎるとマイナス）

## Errors
| Status | error / errors | 内容 |
| ------ | -------------- | ---- |
| 404 | `budget_not_found` | 予算が存在しない、または他ユーザーの予算 |
| 404 | `expense_account_not_found` | 費用科目が存在しない、または他ユーザーの科目 |
| 404 | `tag_not_found` | タグ（除くタグを含む）が存在しない、または他ユーザーのタグ |
| 422 | `errors` | 本文・基準日のバリデーションエラー |

### Authorization Error (401 Unauthorized)

```json
{
  "error": "unauthorized"
}
```
