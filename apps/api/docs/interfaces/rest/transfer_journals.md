# 振替（引き出し・振替・チャージ）API

口座から口座へお金を動かす仕訳（借方: 入れる先の口座、貸方: 出す元の口座かクレジットカード）を登録・修正する REST API。
証券口座への入金や、iDeCo・積立 NISA などの投資の口座への積立もこれで登録する（貸方の `payment_method_type` は出す元の口座の種別）

---

## Endpoint

```text
POST /transfer-journals
PUT  /transfer-journals/{id}
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- 持ち主は認証済みユーザー。本文に `user_id` を送っても無視する
- 出す元・入れる先は本人の口座・カードだけ使える。それ以外は存在しないものと同じ 404 を返す
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
  "journal_date": "2026-11-05",
  "from_type": "asset",
  "from_account_id": 2,
  "to_account_id": 1,
  "amount": 10000,
  "description": ""
}
```

| Name            | Required | Description |
| --------------- | -------- | ----------- |
| journal_date    | Yes      | 日付（`YYYY-MM-DD`） |
| from_type       | Yes      | 出す元の種類。`asset`（口座）か `credit_card`（クレジットカード） |
| from_account_id | Yes      | 出す元の口座、またはカード（負債科目）の ID |
| to_account_id   | Yes      | 入れる先の口座 |
| amount          | Yes      | 金額（1 〜 2147483647） |
| description     | No       | 摘要（100 文字まで）。空なら組み合わせから決める（下の表） |

| 出す元 → 入れる先 | 摘要が空のとき |
| ----------------- | -------------- |
| 預金 → 現金 | 引き出し |
| 現金 → 預金 | 預入 |
| どこから → 電子マネー | チャージ |
| それ以外（預金 → 預金など） | 振替 |

## 登録と修正の仕方
- 登録は DB 関数 `create_transfer_journal`。借方: 入れる先の口座、貸方: 出す元の仕訳を 1 つ作る
- 出す元と入れる先は、同じ口座にできない
- クレジットカードから入れられるのは電子マネーだけ（チャージ）。お買い物のカード払いと同じく、カードの締め日・支払日から引き落とし仕訳を自動で作る（[通帳](bank_account_ledgers.md)に引き落とし予定として出る）
- 修正は DB 関数 `replace_transfer_journal`。振替の仕訳（借方が口座 1 つ、貸方が口座かクレジットカード 1 つ。株数を持つ株の売買は除く）か確かめてから、元の仕訳を削除して、登録と同じ確認をしながら登録し直す。失敗した場合は元の仕訳が残る。**仕訳の ID は変わる**
- 決まった振替（[決まった支払い API](recurring_entries.md)）で登録した仕訳を修正しても、回の記録は新しい仕訳に付いたまま
- 以前の「現金の預け入れ」（[`POST /cash-deposit-journals`](cash_deposit_journals.md)）の仕訳も、振替として修正できる
- カードからのチャージを修正すると、引き落とし仕訳も作り直し、引き落とし日は自動の計算に戻る（手で変えた日を引き継ぐのは、お買い物の修正だけ）
- 手数料は扱わない。手数料はお買い物登録で費用として別に登録する
- 削除は [仕訳削除 API](delete_journal.md) を使う

## Response

### Success
| API | Status | Body |
| --- | ------ | ---- |
| `POST` | 201 Created | `{ "journal_id": 41, "next_token": "..." }` |
| `PUT` | 200 OK | `{ "journal_id": 42, "next_token": "..." }`（作り直した仕訳の新しい ID） |

### Errors
| Status | error / errors | 内容 |
| ------ | -------------- | ---- |
| 404 | `from_account_not_found` | 出す元の口座・カードが存在しない、他ユーザーのもの、またはクレジットカードではない負債科目 |
| 404 | `to_account_not_found` | 入れる先の口座が存在しない、または他ユーザーの口座 |
| 404 | `journal_not_found` | 修正する仕訳が存在しない、または他ユーザーの仕訳（PUT） |
| 422 | `same_account` | 出す元と入れる先が同じ口座 |
| 422 | `credit_card_charge_requires_e_money` | カードから電子マネー以外に入れようとした |
| 422 | `credit_card_setting_not_found` | カードの引き落とし設定が無い |
| 422 | `journal_not_editable` | 振替の仕訳ではない（株の売買を含む。PUT） |
| 422 | `errors` | 本文のバリデーションエラー |

```json
{
  "error": "same_account",
  "next_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

### Authorization Error (401 Unauthorized)

```json
{
  "error": "unauthorized"
}
```
