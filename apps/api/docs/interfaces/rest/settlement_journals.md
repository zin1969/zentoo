# 立替金の精算 API

立て替えた分を返してもらったときの仕訳を登録・修正する REST API（M19）。
立替金は資産で、相手ごとに種別 6（立替金）の口座を作る（例: 「立替金 田中」「立替金 会社」）。

---

## Endpoint

```text
POST /settlement-journals
PUT  /settlement-journals/{id}
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- 持ち主は認証済みユーザー。本文に `user_id` を送っても無視する
- 立替金・入金先は本人の口座、差額の科目は共通か本人の科目だけ使える。それ以外は存在しないものと同じ 404 を返す
- 401 以外では、本文に新しい `next_token` を返す

## Request

### Headers
| Name          | Required | Description      |
| ------------- | -------- | ---------------- |
| Authorization | Yes      | Bearer {token}   |
| Content-Type  | Yes      | application/json |

### Path（PUT）
| Name | Required | Description |
| ---- | -------- | ----------- |
| id   | Yes      | 修正する仕訳の ID（1 以上の整数） |

### Body（POST / PUT）

```json
{
  "journal_date": "2026-12-10",
  "receivable_account_id": 31,
  "settled_amount": 15000,
  "received_amount": 14500,
  "to_account_id": 2,
  "difference_account_id": 3,
  "description": ""
}
```

| Name                  | Required | Description |
| --------------------- | -------- | ----------- |
| journal_date          | Yes      | 日付（`YYYY-MM-DD`） |
| receivable_account_id | Yes      | 立替金の口座（種別 6）の ID |
| settled_amount        | Yes      | 消し込む額（立替金から減らす額。1 〜 2147483647） |
| received_amount       | Yes      | 受け取った額（0 〜 2147483647）。全額おごりになったときは 0 |
| to_account_id         | 受け取った額が 1 以上のとき | 入金先の口座（立替金以外の本人の口座）。受け取った額が 0 なら無視する |
| difference_account_id | 差額があるとき | 差額（消し込む額 − 受け取った額）の科目。少なく受け取ったら費用科目、多く受け取ったら収益科目。差額が無ければ無視する |
| description           | No       | 摘要（100 文字まで）。空なら「精算 立替金の口座名」 |

## 仕訳の作り方

| 場合 | 借方 | 貸方 |
| ---- | ---- | ---- |
| 額どおり | 入金先（受け取った額） | 立替金（消し込む額） |
| 少なく受け取った（会社に認められない分・おごり） | 入金先（受け取った額）、費用（差額） | 立替金（消し込む額） |
| 多く受け取った | 入金先（受け取った額） | 立替金（消し込む額）、収益（差額） |
| 受け取りなし（全額おごり） | 費用（消し込む額） | 立替金（消し込む額） |

- 登録は DB 関数 `create_settlement_journal`、修正は `replace_settlement_journal`（元の仕訳を削除して作り直す。失敗すると元の仕訳が残る。**仕訳の ID は変わる**）
- 貸方の立替金の `payment_method_type` は 6（口座の種別）
- 立替金から出すのは精算だけ。[振替](transfer_journals.md)では立替金から出せない（`receivable_requires_settlement`）。精算の仕訳は、お買い物・振替の修正では直せない
- 立替金の残りより多く消し込んでも断らない（残高がマイナスになる）。残りは [残高 API](account_balances.md) で見る
- 立替金に入れるのは、お買い物の立て替えの明細（[仕訳登録 API](journal_entries.md)）か、振替（例: 仕事で乗った分を PASMO → 立替金 会社）
- 月末の突き合わせは、[仕訳一覧 API](journals.md) で立替金の口座を指定したときの `account_totals`
- 削除は [仕訳削除 API](delete_journal.md)

## Response

### Success
| API | Status | Body |
| --- | ------ | ---- |
| `POST` | 201 Created | `{ "journal_id": 61, "next_token": "..." }` |
| `PUT` | 200 OK | `{ "journal_id": 62, "next_token": "..." }`（作り直した仕訳の新しい ID） |

### Errors
| Status | error / errors | 内容 |
| ------ | -------------- | ---- |
| 404 | `receivable_account_not_found` | 立替金の口座が存在しない、他ユーザーの口座、または種別が立替金ではない |
| 404 | `to_account_not_found` | 入金先が存在しない、他ユーザーの口座、または立替金の口座 |
| 404 | `difference_account_not_found` | 差額の科目が存在しない、他ユーザーの科目、または差額の向きと合わない（少なく受け取ったのに収益科目など） |
| 404 | `journal_not_found` | 修正する仕訳が存在しない、または他ユーザーの仕訳（PUT） |
| 422 | `journal_not_editable` | 精算の仕訳ではない（PUT） |
| 422 | `errors` | 本文のバリデーションエラー |

```json
{
  "error": "difference_account_not_found",
  "next_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

### Authorization Error (401 Unauthorized)

```json
{
  "error": "unauthorized"
}
```
