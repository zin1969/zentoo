# ログイン API

ユーザーを認証し、最初の JWT を発行する REST API

---

## Endpoint

```text
POST /login
```

## Authentication / Authorization
- 認証不要（このエンドポイントがトークンの発行元）
- 同一 IP から 3 分間に 10 回を超えるリクエストは 429 を返す

## Request

### Headers
| Name         | Required | Description      |
| ------------ | -------- | ---------------- |
| Content-Type | Yes      | application/json |

### Body

```json
{
  "name": "masa",
  "password": "********"
}
```

## Response

### Success (201 Created)

```json
{
  "token": "abc.def.ghi"
}
```

`token` は有効期限 15 分の JWT。以降のリクエストでは `Authorization: Bearer {token}` に指定する。

### Authentication Error (401 Unauthorized)

```json
{
  "error": "unauthorized"
}
```

ユーザーが存在しない・パスワードが未設定・パスワードが一致しない場合は、いずれも同じ応答を返す（どれに該当するかは区別しない）。

### Too Many Requests (429)

レスポンスボディなし。

## Notes

- Browser には `token` を渡さない。Next.js（BFF）が httpOnly Cookie に保持する
