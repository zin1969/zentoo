# 決まった支払い API

家賃・サブスク・保険・給料・積立など、決まった周期の支払い・収入・振替を設定し、回ごとに確かめてから仕訳にする REST API

---

## Endpoint

```text
GET    /recurring-entries
POST   /recurring-entries
PUT    /recurring-entries/{id}
DELETE /recurring-entries/{id}
GET    /recurring-entries/pending
POST   /recurring-entries/{id}/occurrences
POST   /recurring-entries/{id}/skips
```

## 決まった支払いの考え方
- 自動では登録しない。未登録の回の一覧（`GET /recurring-entries/pending`）から、金額を確かめて（直して）1 回ずつ登録するか、飛ばす
- 支出（`kind` = 1）は、お買い物と同じ形の仕訳になる（借方: 費用科目、貸方: 支払い方法の口座かカード）。カード払いなら、引き落とし仕訳も今までどおり自動で作られる
- 収入（`kind` = 2）は、収入登録と同じ形の仕訳になる（借方: 入金先の口座、貸方: 収益科目）
- 振替（`kind` = 3）は、振替と同じ形の仕訳になる（借方: 入金先の口座、貸方: 出金元の口座かクレジットカード）。証券口座への入金・積立 NISA・iDeCo・電子マネーのオートチャージなど。カードから入れられるのは電子マネーだけで、カードからのチャージなら引き落とし仕訳も今までどおり自動で作られる。摘要は `store_name`（空なら名前）
- 周期は 2 種類
  - 月単位（`interval_unit` = 1）: 開始日の月から `interval_count` ヶ月ごとの `day_of_month` 日。毎月は 1、3 ヶ月ごとは 3、毎年は 12。月に無い日（2 月 30 日など）は月末にするので、31 は月末
  - 週単位（`interval_unit` = 2）: 開始日から最初の `weekday` 曜日（開始日がその曜日なら開始日）から、`interval_count` 週ごと。隔週は 2
- 土日・祝日でも日をずらさない（カードの引き落としとは違う）
- 開始日より前・終了日より後の回は出さない
- 回ごとに「どの予定日の分を、どの仕訳で登録したか（または飛ばしたか）」を記録する。同じ回は 1 度しか記録できない
- 登録した仕訳を削除すると、その回はまた未登録に戻る。仕訳を修正（削除して作り直す）しても、記録は新しい仕訳に付いたまま
- 決まった支払いで使っている口座・カード・科目は、仕訳で使っているときと同じく削除できない（[口座・科目の管理 API](account_management.md)）

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- 認証済みユーザーの決まった支払いだけ扱える。他ユーザーのものは、存在しないものと同じ 404 を返す
- `GET` は新しいトークンをレスポンスヘッダ `X-Next-Token` で返す
- `POST` / `PUT` は本文に新しい `next_token` を返す（エラー時も、401 を除いて返す）
- `DELETE` は成功時に本文を返さない（204）。新しいトークンはレスポンスヘッダ `X-Next-Token` で返す

## 設定（`/recurring-entries`）

### Body（POST / PUT）

```json
{
  "name": "家賃",
  "kind": 1,
  "store_name": "大家",
  "item_name": "",
  "amount": 85000,
  "debit_account_id": 12,
  "credit_element_type": 1,
  "credit_account_id": 2,
  "interval_unit": 1,
  "interval_count": 1,
  "day_of_month": 27,
  "weekday": null,
  "start_date": "2026-11-01",
  "end_date": null
}
```

| Name | Required | Description |
| ---- | -------- | ----------- |
| name | Yes | 名前（前後の空白は取り除く。30 文字まで） |
| kind | Yes | 1 = 支出、2 = 収入、3 = 振替 |
| store_name | No | 仕訳の店舗名（収入・振替では摘要。空なら名前）。100 文字まで |
| item_name | No | 支出の明細の品目（空なら名前）。100 文字まで。振替では保存しない |
| amount | Yes | 目安の金額（1 以上の整数）。登録のときに直せる |
| debit_account_id | Yes | 支出は費用科目、収入・振替は入金先の口座 |
| credit_element_type | Yes | 支出は 1（口座）か 2（カード・借入）、収入は 4（収益科目）、振替は 1（口座）か 2（カード） |
| credit_account_id | Yes | 支出は支払い方法の口座・カード、収入は収益科目、振替は出金元の口座・カード（振替では入金先と同じ口座は不可） |
| interval_unit | Yes | 1 = 月単位、2 = 週単位 |
| interval_count | Yes | 何ヶ月（何週）ごとか。1〜12 |
| day_of_month | 月単位で Yes | 1〜31（31 は月末）。週単位では無視する |
| weekday | 週単位で Yes | 0 = 日曜 … 6 = 土曜。月単位では無視する |
| start_date | Yes | 開始日 |
| end_date | No | 終了日（開始日以降） |

- 費用・収益科目は共通科目か本人の科目、口座・カードは本人のものだけ使える。入金先・支払い方法の口座は、預金口座も選べる（口座振替の家賃など）

### `GET /recurring-entries`（200 OK）

作った順に返す。

```json
[
  {
    "id": 1, "name": "家賃", "kind": 1, "store_name": "大家", "item_name": null, "amount": 85000,
    "debit_account_id": 12, "debit_account_name": "家賃",
    "credit_element_type": 1, "credit_account_id": 2, "credit_account_name": "三菱UFJ銀行 用賀出張所",
    "interval_unit": 1, "interval_count": 1, "day_of_month": 27, "weekday": null,
    "start_date": "2026-11-01", "end_date": null, "next_date": "2026-11-27"
  }
]
```

- `next_date`: 今日以降の次の予定日。終了していれば `null`

### `POST /recurring-entries`（201 Created）・`PUT /recurring-entries/{id}`（200 OK）

```json
{
  "id": 1,
  "next_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

- 変更しても、すでに登録・飛ばした回の記録はそのまま残る

### `DELETE /recurring-entries/{id}`（204 No Content）

本文なし。回の記録も一緒に消える。登録した仕訳は残る。

## 今月の分

### `GET /recurring-entries/pending`（200 OK）

今月の末日までの、まだ登録も飛ばしもしていない回を、予定日の順に返す。開始日から数えるので、先月以前の取り残しも含む。

```json
[
  {
    "recurring_entry_id": 1, "scheduled_date": "2026-11-27",
    "name": "家賃", "kind": 1, "amount": 85000, "store_name": "大家", "item_name": null,
    "debit_account_name": "家賃", "credit_account_name": "三菱UFJ銀行 用賀出張所",
    "interval_unit": 1, "interval_count": 1
  }
]
```

### `POST /recurring-entries/{id}/occurrences`（201 Created）

回を、確かめた金額で仕訳にする。

```json
{
  "scheduled_date": "2026-11-27",
  "date": "2026-11-28",
  "amount": 86000
}
```

| Name | Required | Description |
| ---- | -------- | ----------- |
| scheduled_date | Yes | 登録する回の予定日 |
| date | No | 仕訳の日付。省略すると予定日（遅れて払ったときなどに変える） |
| amount | Yes | 確かめた（直した）金額（1 以上の整数） |

```json
{
  "journal_id": 120,
  "next_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

### `POST /recurring-entries/{id}/skips`（201 Created）

回を「今回はなし」にする。仕訳は作らない。

```json
{
  "scheduled_date": "2026-11-27"
}
```

```json
{
  "next_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

## Errors
| Status | error / errors | 内容 |
| ------ | -------------- | ---- |
| 404 | `recurring_entry_not_found` | 決まった支払いが存在しない、または他ユーザーのもの |
| 404 | `account_not_found` | 科目・口座・カードが存在しない、使えない、または種類に合わない（登録のときは、設定のあとで使えなくなった場合） |
| 422 | `not_scheduled_date` | 登録・飛ばす日が、その決まった支払いの予定日ではない |
| 422 | `occurrence_already_recorded` | その回はすでに登録したか、飛ばしてある |
| 422 | `credit_card_setting_not_found` | カード払い（カードからのチャージ）なのに、カードの引き落とし設定が無い |
| 422 | `same_account` | 振替の登録で、出金元と入金先が同じ口座 |
| 422 | `credit_card_charge_requires_e_money` | 振替の登録で、カードからの入金先が電子マネーではない（設定のあとで口座の種別を変えた場合など） |
| 422 | `errors` | 値が範囲外・足りない（金額、周期、日・曜日、終了日が開始日より前、振替で出金元と入金先が同じ口座など） |

### Authorization Error (401 Unauthorized)

```json
{
  "error": "unauthorized"
}
```
