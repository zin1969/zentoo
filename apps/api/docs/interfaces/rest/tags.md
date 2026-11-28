# タグ API

明細に付ける「何のために使ったか」（勉強・娯楽・一人飲みなど）を管理する REST API

---

## Endpoint

```text
GET    /tags
POST   /tags
PUT    /tags/{id}
DELETE /tags/{id}
```

## タグの考え方
- 科目は「何に使ったか」（書籍・外食費）、タグは「何のために使ったか」（勉強・娯楽）。目的で科目を細かく分けず、タグで管理・集計する
- タグは複式簿記の外の情報で、残高・貸借には影響しない
- タグはユーザーごと。名前はユーザーの中で重ならない
- 明細（借方の 1 行）とタグは多対多（`debit_tags`）。付けられるのは、お買い物の費用の明細だけ。付け方は [仕訳登録 API](journal_entries.md) の `tag_ids`
- 集計は [タグの集計 API](tag_reports.md)

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- 認証済みユーザーのタグだけ扱える。他ユーザーのタグは、存在しないタグと同じ 404 を返す
- `GET` は新しいトークンをレスポンスヘッダ `X-Next-Token` で返す
- `POST` / `PUT` は本文に新しい `next_token` を返す（エラー時も、401 を除いて返す）
- `DELETE` は成功時に本文を返さない（204）。新しいトークンはレスポンスヘッダ `X-Next-Token` で返す

## Request

### Body（POST / PUT）

```json
{
  "name": "勉強"
}
```

| Name | Required | Description |
| ---- | -------- | ----------- |
| name | Yes      | タグの名前（前後の空白は取り除く。30 文字まで） |

## Response

### `GET /tags`（200 OK）

作った順に返す（日本語の名前の並びは読みの順にならないため）。

```json
[
  { "id": 3, "name": "勉強", "usage_count": 12 },
  { "id": 4, "name": "娯楽", "usage_count": 5 }
]
```

- `usage_count`: タグが付いている明細の数

### `POST /tags`（201 Created）・`PUT /tags/{id}`（200 OK）

```json
{
  "id": 5,
  "name": "一人飲み",
  "next_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

- 名前を変えると、付いている明細のタグも新しい名前で表示される

### `DELETE /tags/{id}`（204 No Content）

本文なし。使っているタグも削除でき、明細からタグが外れるだけで、明細は消えない。[予算](budgets.md)の除くタグからも外れる。予算の対象にしているタグは削除できない（先に予算を削除するか、対象を変える）。

### Errors
| Status | error / errors | 内容 |
| ------ | -------------- | ---- |
| 404 | `tag_not_found` | タグが存在しない、または他ユーザーのタグ |
| 422 | `duplicate_tag_name` | 同じ名前のタグがある |
| 422 | `tag_used_by_budget` | 予算の対象にしているタグの削除 |
| 422 | `errors` | 名前が空、または 30 文字を超える |

### Authorization Error (401 Unauthorized)

```json
{
  "error": "unauthorized"
}
```
