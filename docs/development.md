# 開発手順

Docker は Vagrant 上の Debian で動かす。以下のコマンドはリポジトリのルートで、Vagrant 内から実行する。

```
docker-compose -f docker-compose/docker-compose.yaml ...
```

## 起動

```
docker-compose -f docker-compose/docker-compose.yaml up
```

| サービス | URL |
|----------|-----|
| web (Next.js) | http://localhost:53001 |
| api (Rails) | http://localhost:53000 |
| db (PostgreSQL) | localhost:55432 |

api の起動時に `bin/rails db:prepare` が走る。

## 初期データ（開発用ユーザーを含む）

マイグレーション後にシードを投入する。何度実行しても重複しない。

```
docker-compose -f docker-compose/docker-compose.yaml run --rm --no-deps api bin/rails db:migrate
docker-compose -f docker-compose/docker-compose.yaml run --rm api bin/rails db:seed
```

### ログインできるユーザー

| ユーザー名 | パスワード | 備考 |
|------------|------------|------|
| `masa` | `password`（開発・テスト環境の既定値） | 勘定科目のシードはこのユーザーに紐づく |
| `system` | なし | ログイン不可 |

- パスワードを変えたい場合は、環境変数 `SEED_USER_PASSWORD` を指定してシードを実行する。**既にパスワードが設定されている場合は上書きしない**ので、変える場合は先に `bin/rails runner 'User.find_by!(name: "masa").update!(password: nil)'` で消す。
- 本番環境では `SEED_USER_PASSWORD` が必須（未指定ならシードがエラーになる）。既定値の `password` が本番に入ることはない。

## テストと CI 相当のチェック

CI（`.github/workflows/ci.yml`）と同じ内容を手元で確認する場合。

```
docker-compose -f docker-compose/docker-compose.yaml run --rm --service-ports -e CI=true api rspec
docker-compose -f docker-compose/docker-compose.yaml run --rm --no-deps api bin/rubocop
docker-compose -f docker-compose/docker-compose.yaml run --rm --no-deps api bin/brakeman --no-pager
docker-compose -f docker-compose/docker-compose.yaml run --rm --no-deps api bin/bundler-audit
```

Web（`apps/web`）の確認は `next` コンテナ内で行う。

```
docker-compose -f docker-compose/docker-compose.yaml run --rm --no-deps next npx tsc --noEmit
docker-compose -f docker-compose/docker-compose.yaml run --rm --no-deps next npm run lint
```
