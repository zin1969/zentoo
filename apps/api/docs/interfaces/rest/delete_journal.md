# 仕訳削除 API

認証済みユーザーの仕訳を削除する REST API

---

## Endpoint

```text
DELETE /journals/{id}
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- 認証済みユーザーの仕訳のみ削除できる。他ユーザーの仕訳は、存在しない仕訳と同じ 404 を返す
- 成功時は本文を返さないので、新しいトークンはレスポンスヘッダ `X-Next-Token` で返す（エラー時も同じ。401 を除く）

## Request

### Headers
| Name          | Required | Description    |
| ------------- | -------- | -------------- |
| Authorization | Yes      | Bearer {token} |

### Path
| Name | Required | Description |
| ---- | -------- | ----------- |
| id   | Yes      | 削除する仕訳の ID（1 以上の整数） |

## 削除される仕訳
- 指定した仕訳と、その借方・貸方を DB から完全に削除する。元に戻せない（取消仕訳は作らない）
- クレジットカード払いの仕訳（お買い物・開始負債）は、自動で作られた引き落とし仕訳も一緒に削除する。引き落とし日を過ぎていても同じ
- 引き落とし仕訳だけを削除することはできない。元のカード払い仕訳を削除する

## Response

### Success (204 No Content)

本文なし。

### Not Found (404 Not Found)

仕訳が存在しない、または他ユーザーの仕訳。

```json
{
  "error": "journal_not_found"
}
```

### Not Deletable (422 Unprocessable Entity)

引き落とし仕訳を指定した。

```json
{
  "error": "direct_debit_journal_not_deletable"
}
```

### Authorization Error (401 Unauthorized)

```json
{
  "error": "unauthorized"
}
```
