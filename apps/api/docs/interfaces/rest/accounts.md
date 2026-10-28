# 勘定科目マスタ API

認証済みユーザーの勘定科目を取得する REST API

---

## Endpoint

```text
GET /asset-accounts
GET /liability-accounts
GET /expense-accounts
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- 認証済みユーザーの勘定科目のみ返す（他ユーザーの科目は返らない）
- 配列を返すため `next_token` は返却しない（トークンのローテーションは行わない）

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
  { "id": 1, "name": "現金", "element_type": 1, "payment_method_type": 1 }
]
```

`payment_method_type`: 1 = 現金, 2 = 預貯金, 3 = 電子マネー

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
  { "id": 1, "name": "食費" }
]
```

### Authentication Error (401 Unauthorized)

```json
{
  "error": "unauthorized"
}
```
