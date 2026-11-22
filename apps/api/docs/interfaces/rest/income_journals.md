# 収入の登録・修正 API

給料などの収入の仕訳（借方: 入金先の口座、貸方: 収益科目）を登録・修正する REST API

---

## Endpoint

```text
POST /income-journals
PUT  /income-journals/{id}
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- 持ち主は認証済みユーザー。本文に `user_id` を送っても無視する
- 入金先の口座は本人のもの、収益科目は共通科目か本人の科目だけ使える。それ以外は存在しないものと同じ 404 を返す
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
  "journal_date": "2026-11-25",
  "asset_account_id": 2,
  "revenue_account_id": 1,
  "amount": 300000,
  "description": "ゼンギン株式会社"
}
```

| Name               | Required | Description |
| ------------------ | -------- | ----------- |
| journal_date       | Yes      | 日付（`YYYY-MM-DD`） |
| asset_account_id   | Yes      | 入金先の口座。預金・現金・電子マネーのどれでもよい |
| revenue_account_id | Yes      | 収益科目。親の科目も選べる |
| amount             | Yes      | 金額（1 〜 2147483647） |
| description        | No       | 摘要（支払元など。100 文字まで）。仕訳の店舗名に入れ、空なら収益科目の名前を入れる（通帳の摘要に出る） |

## 登録と修正の仕方
- 登録は DB 関数 `create_income_journal`。借方: 入金先の口座（金額）、貸方: 収益科目（金額）の仕訳を 1 つ作る
- 修正は DB 関数 `replace_income_journal`。収入の仕訳（貸方がすべて収益）か確かめてから、元の仕訳を削除して、登録と同じ確認をしながら登録し直す。失敗した場合は元の仕訳が残る。**仕訳の ID は変わる**
- 削除は [仕訳削除 API](delete_journal.md) を使う
- 登録した収入は、残高・[通帳](bank_account_ledgers.md)・[月次の収支](monthly_expenses.md)に反映される

## Response

### Success
| API | Status | Body |
| --- | ------ | ---- |
| `POST` | 201 Created | `{ "journal_id": 31, "next_token": "..." }` |
| `PUT` | 200 OK | `{ "journal_id": 32, "next_token": "..." }`（作り直した仕訳の新しい ID） |

### Errors
| Status | error / errors | 内容 |
| ------ | -------------- | ---- |
| 404 | `asset_account_not_found` | 入金先の口座が存在しない、または他ユーザーの口座 |
| 404 | `revenue_account_not_found` | 収益科目が存在しない、または他ユーザーの科目 |
| 404 | `journal_not_found` | 修正する仕訳が存在しない、または他ユーザーの仕訳（PUT） |
| 422 | `journal_not_editable` | 収入の仕訳ではない（PUT） |
| 422 | `errors` | 本文のバリデーションエラー |

```json
{
  "error": "revenue_account_not_found",
  "next_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

### Authorization Error (401 Unauthorized)

```json
{
  "error": "unauthorized"
}
```
