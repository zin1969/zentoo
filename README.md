# zentoo

複式簿記の考え方を取り入れたお小遣い帳システム。

## 構成（モノリポ）

| パス | 内容 | 旧リポジトリ |
|------|------|--------------|
| `apps/api/` | Rails API + CI + Kamal | `zin1969/zentoo_api` |
| `apps/web/` | Next.js / React フロントエンド | `zin1969/zentoo_nextjs-app` |
| `db/` | 生SQL / PL/pgSQL function・テストデータ | `zin1969/zentoo_db` |
| `design/` | OpenAPI 定義 | `zin1969/zentoo_design` |
| `docs/rules/` | コーディング規約 | `zin1969/rules` |
| `docker-compose/` | 開発用 compose・運用メモ | `zin1969/zentoo_docker-compose` |
| `docs/` | プロダクトアウトライン・スプリント計画 | （旧 `zentoo/` 直下） |

各ディレクトリの履歴は `git subtree` で取り込み済み。`git log -- apps/api` / `git blame` は移行前のコミットまで遡れる。

## 開発

```
cd docker-compose && docker compose -f docker-compose.yaml up
```

詳細は各ディレクトリの README / operation.txt を参照。
