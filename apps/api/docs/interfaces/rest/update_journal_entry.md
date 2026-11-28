# お買い物の仕訳 修正 API

認証済みユーザーのお買い物の仕訳を、新しい内容で作り直す REST API

---

## Endpoint

```text
PUT /journal-entries/{id}
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- 認証済みユーザーの仕訳のみ修正できる。他ユーザーの仕訳は、存在しない仕訳と同じ 404 を返す
- 401 以外では、本文に新しい `next_token` を返す

## Request

### Headers
| Name          | Required | Description      |
| ------------- | -------- | ---------------- |
| Authorization | Yes      | Bearer {token}   |
| Content-Type  | Yes      | application/json |

### Path
| Name | Required | Description |
| ---- | -------- | ----------- |
| id   | Yes      | 修正する仕訳の ID（1 以上の整数） |

### Body

[仕訳登録 API](journal_entries.md) と同じ。ただし借方（`debits`）はすべて費用（`element_type` が 5）にする。`user_id` は送っても無視する。明細のタグ（`tag_ids`）は、送った内容で作り直す（送らなければタグは外れる）。

## 修正の仕方
- DB 関数 `replace_journal_entry` が、元の仕訳を削除して、新しい内容で登録し直す。登録と同じ確認（貸借の一致、科目の持ち主、カードの引き落とし設定）を行う
- 確認で失敗した場合は、元の仕訳がそのまま残る
- **仕訳の ID は変わる**。レスポンスの `journal_id` が新しい ID
- カード払いの引き落とし仕訳も作り直す。現金払いとカード払いを切り替えた場合も、引き落とし仕訳が正しく作られる（または消える）
- 修正できるのはお買い物の仕訳（借方がすべて費用か立替金。全額を立て替えて費用の明細が無いものも含む）だけ。精算は [精算の修正](settlement_journals.md) で直す。収入は [収入の修正](income_journals.md)、振替（以前の預け入れを含む）は [振替の修正](transfer_journals.md) で直す。引き落とし仕訳の日付は [引き落とし日の変更](direct_debit_journals.md)。開始残高は修正できない（削除して登録し直す）

## Response

### Success (200 OK)

```json
{
  "journal_id": 21,
  "next_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

### Not Found (404 Not Found)

| error | 内容 |
| ----- | ---- |
| `journal_not_found` | 仕訳が存在しない、または他ユーザーの仕訳 |
| `account_not_found` | 借方・貸方の科目が存在しない、または使えない |

```json
{
  "error": "journal_not_found",
  "next_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

### Unprocessable (422 Unprocessable Entity)

| error / errors | 内容 |
| -------------- | ---- |
| `errors` | 本文のバリデーションエラー |
| `direct_debit_journal_not_editable` | 引き落とし仕訳を指定した |
| `journal_not_editable` | お買い物の仕訳ではない（開始残高、預け入れなど） |
| `expense_debits_required` | 借方に費用と本人の立替金以外の科目がある |
| `unbalanced_journal` | 借方と貸方の合計が一致しない |
| `credit_card_setting_not_found` | カード払いなのに、カードの引き落とし設定が無い |

```json
{
  "error": "journal_not_editable",
  "next_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

### Authorization Error (401 Unauthorized)

```json
{
  "error": "unauthorized"
}
```
