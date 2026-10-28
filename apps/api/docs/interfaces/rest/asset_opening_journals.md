# 開始資産仕訳 API

開始資産を登録するための REST API

---

## Endpoint

```text
POST /asset-opening-journals
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- トークンはワンタイムであり、レスポンスごとに更新される

## Request

### Headers
| Name          | Required | Description             |
| ------------- | -------- | ----------------------- |
| Authorization | Yes      | Bearer {one-time-token} |
| Content-Type  | Yes      | application/json        |

### Body

```json
{
  "journal_date": "2026-02-01",
  "asset_type": 1,
  "asset_account_id": 123,
  "amount": 100000
}
```

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
  "errors": {
    "asset_type": ["must be an ElementType"]
  },
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

指定した勘定科目が存在しない、または認証済みユーザーの科目ではない場合。両者は区別しない。

```json
{
  "error": "asset_account_not_found",
  "next_token": "abc.def.ghi"
}
```

### Business Error (409 Conflict:重複)

```json
{
  "error": "opening_asset_already_exists",
  "next_token": "abc.def.ghi"
}
```

## Notes

- 成功・バリデーションエラー・業務エラーの場合、`next_token` を返却する
- 認可エラー（401）の場合、`next_token` は返却しない
