# カードの引き落とし日 変更 API

カード払いから自動で作られた引き落とし仕訳の日付だけを変える REST API

---

## Endpoint

```text
PUT /direct-debit-journals/{id}
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- 認証済みユーザーの仕訳のみ変更できる。他ユーザーの仕訳は、存在しない仕訳と同じ 404 を返す
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
| id   | Yes      | 引き落とし仕訳の ID（元のカード払い仕訳の ID ではない） |

### Body

```json
{
  "payment_date": "2026-11-27"
}
```

| Name         | Required | Description |
| ------------ | -------- | ----------- |
| payment_date | Yes      | 新しい引き落とし日（`YYYY-MM-DD`） |

## 変更の仕方
- 引き落とし仕訳の日付だけを変える。金額・科目・引き落とし口座は変えない。仕訳の ID も変わらない
- 元の仕訳の日付（お買い物なら買った日、開始負債なら開始日）より前にはできない。それ以外は自由で、土日・祝日でも営業日にずらさない（カードの明細の日付をそのまま入れる想定）
- 変えた引き落とし仕訳は、[仕訳一覧 API](journals.md) の `payment_date_overridden` が `true` になる
- 元のお買い物を[修正](update_journal_entry.md)しても、同じカード 1 枚での支払いのままで、修正後の買った日が変えた日より後にならなければ、変えた日を引き継ぐ。それ以外は、締め日・支払日からの自動の計算に戻る

## Response

### Success (200 OK)

`journal_id` は引き落とし仕訳の ID（変わらない）。

```json
{
  "journal_id": 15,
  "next_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

### Not Found (404 Not Found)

仕訳が存在しない、または他ユーザーの仕訳。

```json
{
  "error": "journal_not_found",
  "next_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

### Unprocessable (422 Unprocessable Entity)

| error / errors | 内容 |
| -------------- | ---- |
| `errors` | `payment_date` が無い、または日付ではない |
| `not_direct_debit_journal` | 引き落とし仕訳ではない仕訳を指定した |
| `payment_date_before_journal_date` | 元の仕訳の日付より前の日付を指定した |

```json
{
  "error": "payment_date_before_journal_date",
  "next_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

### Authorization Error (401 Unauthorized)

```json
{
  "error": "unauthorized"
}
```
