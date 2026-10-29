# 仕訳登録 API

借方・貸方を指定して仕訳（お買い物など）を登録する REST API

---

## Endpoint

```text
POST /journal-entries
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- トークンはワンタイムであり、レスポンスごとに更新される
- 仕訳の持ち主は認証済みユーザーになる（リクエストの `user_id` は検証だけに使い、値は無視される）
- 使える科目: 資産・負債科目は本人のもののみ。費用・資本科目は共通科目（全ユーザー共通）と本人の科目

## Request

### Headers
| Name          | Required | Description             |
| ------------- | -------- | ----------------------- |
| Authorization | Yes      | Bearer {one-time-token} |
| Content-Type  | Yes      | application/json        |

### Body

```json
{
  "date": "2026-07-19",
  "user_id": 0,
  "store_name": "ピザーラ",
  "debits": [
    { "element_type": 5, "account_id": 10051, "amount": 1000, "item_name": "ピザ" }
  ],
  "credits": [
    { "element_type": 1, "payment_method_type": 1, "account_id": 5, "amount": 1000 }
  ]
}
```

- `element_type`: 1 = 資産, 2 = 負債, 3 = 資本, 5 = 費用
- `payment_method_type`（貸方）: 資産科目は 1 = 現金, 2 = 預貯金, 3 = 電子マネー。負債科目は 1 = 借入金, 2 = キャッシング, 3 = クレジットカード払い
- 借方の合計と貸方の合計は一致していること

## クレジットカード払いの引き落とし仕訳

貸方が負債科目のクレジットカード払い（`element_type` = 2、`payment_method_type` = 3）の場合、登録と同時に引き落とし日の仕訳が自動で作られる。

- 日付: カード設定の締日・支払日から計算する。月に存在しない日（2 月 30 日など）は月末日に丸め、土日・祝日・銀行休日なら翌営業日にずらす
- 借方: カードの負債科目（項目名は元の仕訳の借方の項目名をカンマでつないだもの）、貸方: カード設定の引き落とし口座
- 元の仕訳と引き落とし仕訳は `direct_debit_journals` で紐付く
- 祝日・銀行休日は `holidays` テーブルの登録期間のみ考慮される（未登録の期間は土日だけで判定）

## Response

### Success (201 Created)

```json
{
  "journal_id": 456,
  "next_token": "abc.def.ghi"
}
```

### Validation Error (422 Unprocessable Entity)

```json
{
  "errors": ["Validation failed: Date can't be blank"],
  "next_token": "abc.def.ghi"
}
```

### Unbalanced (422 Unprocessable Entity)

```json
{
  "error": "unbalanced_journal",
  "next_token": "abc.def.ghi"
}
```

### Credit Card Setting Not Found (422 Unprocessable Entity)

カード払いの科目に、締日・支払日・引き落とし口座の設定がない場合。

```json
{
  "error": "credit_card_setting_not_found",
  "next_token": "abc.def.ghi"
}
```

### Authorization Error (401 Unauthorized)

```json
{
  "error": "unauthorized"
}
```

### Not Found (404 Not Found)

借方・貸方のいずれかの科目が存在しない、または使えない科目（他ユーザーの資産・負債・費用・資本科目）の場合。両者は区別しない。

```json
{
  "error": "account_not_found",
  "next_token": "abc.def.ghi"
}
```

## Notes

- 成功・バリデーションエラー・業務エラーの場合、`next_token` を返却する
- 認可エラー（401）の場合、`next_token` は返却しない
