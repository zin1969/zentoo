# 勘定科目マスタ API

認証済みユーザーの勘定科目を取得する REST API。追加・変更・削除は [口座・カード・費用科目の管理 API](account_management.md)

---

## Endpoint

```text
GET /asset-accounts
GET /liability-accounts
GET /expense-accounts
GET /revenue-accounts
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- 資産・負債科目は認証済みユーザーのもののみ返す（他ユーザーの科目は返らない）
- 費用科目・収益科目は、全ユーザー共通の科目（`user_id` が NULL）と認証済みユーザー自身の科目を返す
- 配列を返すため本文に `next_token` は含めない。新しいトークンはレスポンスヘッダ `X-Next-Token` で返す（画面を開いたままでも期限切れにならないよう、BFF が Cookie を更新する）

## Request

### Headers
| Name          | Required | Description  |
| ------------- | -------- | ------------ |
| Authorization | Yes      | Bearer {token} |

## Response

### Success (200 OK)

`GET /asset-accounts`

```json
[
  { "id": 1, "name": "現金", "element_type": 1, "payment_method_type": 1, "in_use": true }
]
```

- `payment_method_type`: 1 = 現金, 2 = 預貯金, 3 = 電子マネー
- `in_use`: 仕訳か決まった支払いで使われているか、カードの引き落とし口座になっている。true の口座は名前だけ変えられる

`GET /liability-accounts`

```json
[
  { "id": 1, "name": "JAL", "element_type": 2, "payment_method_type": 3 }
]
```

`payment_method_type`: 1 = 借入金, 2 = キャッシング, 3 = クレジットカード払い

`GET /expense-accounts`

```json
[
  { "id": 1, "name": "食費", "parent_id": null, "in_use": false, "has_children": true },
  { "id": 5, "name": "外食費", "parent_id": 1, "in_use": true, "has_children": false }
]
```

- `parent_id`: 親の科目の ID（トップレベルの科目は null）
- `in_use`: 仕訳（全ユーザー）か決まった支払いで使われている。true の科目は名前だけ変えられる
- `has_children`: 子科目がある。true の科目は削除できない

`GET /revenue-accounts`（収益科目）も、同じ形で返す

### Authentication Error (401 Unauthorized)

```json
{
  "error": "unauthorized"
}
```
