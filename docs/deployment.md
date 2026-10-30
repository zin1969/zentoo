# 本番環境の手順

本番で動かすための設定と手順。開発の手順は [development.md](development.md)、現在地は [milestones.md](milestones.md) を参照。

このドキュメントは、置き場所（VPS + Kamal、将来の PaaS）に依存しない部分を書く。置き場所ごとの設定（Kamal の `deploy.yml`、バックアップなど）は、準備が済んでから「置き場所ごとの設定」に追記する。

## 構成の考え方

```text
ブラウザ ──HTTPS──▶ Next.js (apps/web) ──内部ネットワークの HTTP──▶ Rails API (apps/api) ──▶ PostgreSQL
```

- **公開するのは Next.js だけ**。Rails API は外部に公開せず、Next.js からだけ呼ぶ。
- **HTTPS が必須**。ログイン後のトークンは Cookie（`Secure`、`HttpOnly`）に入れる。HTTPS でない場所では Cookie が保存されず、ログインできない。ドメインを用意して、手前のプロキシで TLS を終端する。
- プロキシは **`Host` ヘッダーをそのまま Next.js に渡す**こと。Next.js は、POST の `Origin` と `Host` が一致するかで CSRF を防いでいる。
- Rails は、すべてのアクセスを HTTPS とみなす設定（`assume_ssl`、`force_ssl`）にしてある。そのため、Next.js から内部ネットワークの HTTP で呼んでもリダイレクトされない。
- Rails のヘルスチェックは `/up`、Next.js のヘルスチェックは `/login`（どちらも認証なしで 200 を返す）。

## 設定（環境変数）

設定はすべて環境変数で渡す。イメージには秘密情報を入れない。

### Rails API（`apps/api/Dockerfile`）

| 名前 | 必須 | 内容 |
|------|------|------|
| `SECRET_KEY_BASE` | はい | Rails の秘密鍵。`openssl rand -hex 64` で作る |
| `JWT_SECRET_KEY` | はい（実質） | ログインのトークンの署名鍵。`openssl rand -hex 32` で作る。未指定なら `SECRET_KEY_BASE` を使う |
| `DATABASE_URL` | どちらか | DB の接続先（例: `postgres://user:password@host:5432/app_production`）。PaaS の標準 |
| `DB_HOST` `DB_PORT` `DB_USER` `DB_PASSWORD` `DB_NAME` | どちらか | `DATABASE_URL` を使わない場合の接続先。`DB_NAME` の既定値は `app_production` |
| `SEED_USER_PASSWORD` | 初回のみ | ログインユーザー（`masa`）のパスワード。DB が空の初回起動に必須（後述） |
| `RAILS_LOG_LEVEL` | いいえ | ログの詳細さ。既定値は `info` |
| `PORT` | いいえ | 待ち受けるポート。既定値は `3000` |

- **`RAILS_MASTER_KEY` は使わない**。`config/credentials.yml.enc` の中身は参照していないので、渡さなくてよい。
- `JWT_SECRET_KEY` を変えると、発行済みのトークンがすべて無効になり、全員がログインし直しになる。
- 秘密情報は、パスワード管理ツールで作って保管する。リポジトリに書かない。
- 本番は **DB を 1 つ**だけ使う（Solid Queue / Cache / Cable は使っていない）。

### Next.js（`apps/web/Dockerfile`）

| 名前 | 必須 | 内容 |
|------|------|------|
| `RAILS_API_URL` | はい | Rails API の URL（例: `http://api:3000`）。内部ネットワークの名前で指定する |
| `PORT` | いいえ | 待ち受けるポート。既定値は `3000` |

## イメージのビルド

リポジトリのルートで実行する。コンテキストは各アプリのフォルダで、その中の `Dockerfile` が使われる。

```
docker build -t zentoo-api apps/api
docker build -t zentoo-web apps/web
```

## 初回起動の流れ

Rails のコンテナは、起動のたびに次の順で動く（`apps/api/bin/docker-entrypoint`）。

1. `db:prepare`: DB がなければ作り、スキーマ（`db/structure.sql`）を読み込む。あればマイグレーションを実行する。DB が新しいときは、**そのまま seed も実行する**。
2. パスワードを持つユーザーがいなければ、`db:seed` を実行する。
3. Rails（Puma）を起動する。

そのため、**空の DB で最初に起動するときは、`SEED_USER_PASSWORD` を付ける**。seed が、次のものを入れる。

- ユーザー（`masa`、パスワードは `SEED_USER_PASSWORD`。`system` はログイン不可）
- 共通の費用科目・資本科目、祝日（2025〜2027 年）
- `masa` の口座・カード・引き落とし設定、店名

### `SEED_USER_PASSWORD` を付け忘れたとき

コンテナは「`SEED_USER_PASSWORD is required in production`」で止まる。環境変数を足して、起動し直せばよい。2 の確認で、パスワードを持つユーザーがいないと判断して、seed をやり直す。DB を作り直す必要はない。

### 注意

- パスワードは、ユーザーに**パスワードがまだないときだけ**設定される。2 回目以降の起動で `SEED_USER_PASSWORD` を変えても、パスワードは変わらない。
- パスワードを変えるときは、Rails のコンテナ内で実行する。

  ```
  bin/rails runner 'User.find_by!(name: "masa").update!(password: ENV.fetch("NEW_PASSWORD"))'
  ```

- seed は何度実行しても重複しない。実行し直すときは、`bin/rails db:seed` をコンテナ内で実行する。
- 起動のたびにマイグレーションが走るので、Rails のコンテナは **1 つだけ**動かす（複数あると、同時にマイグレーションが走る）。
- ログインの試行回数の制限（3 分に 10 回）は、メモリの中で数えている。コンテナを再起動すると、数え直しになる。接続元は Next.js のコンテナになるため、全員で共有される。

## 開始残高の登録

seed のあと、実際の残高を画面から登録する。**仕訳の修正・削除はまだできない**。金額と日付は、登録前に必ず確認する。

1. ログインする（ユーザー名 `masa`、パスワードは `SEED_USER_PASSWORD`）。
2. **開始資産登録**（`/asset-opening-journals`）: 現金・各銀行口座・電子マネーの残高を、1 科目ずつ登録する。開始日は全科目で同じ日にそろえる。同じ科目の二重登録は、エラー（409）になる。
3. **開始負債登録**（`/liability-opening-journals`）: 開始日の時点で未払いのカードの残高を、**引き落とし日ごと**に登録する。引き落とし日は、カードの明細にある支払日をそのまま入れる。同じカードでも、引き落とし日が違えば別々に登録する。
4. **残高**（`/account-balances`）で、開始日の資産・負債が実際と合っていることを確認する。引き落とし日の画面で、負債が減って銀行の残高が減ることも確認できる。

## 動作確認のチェックリスト

本番で、スマホから次を確認する。

- [ ] ログインできる。画面を開いたまま 15 分以上たっても、ログイン画面に戻されない
- [ ] 開始資産・開始負債を登録できる。残高が実際と合う
- [ ] お買い物登録で、現金払い・カード払いができる。カード払いで、引き落とし仕訳が自動で作られる
- [ ] 現金の預け入れを登録できる。現金が減り、預金口座が増える
- [ ] 仕訳一覧に、登録した仕訳が出る
- [ ] 残高と月次の支出が、期待どおりに出る

## 運用メモ

- **祝日データは 2027 年分までしかない**。引き落とし日の営業日計算に使う。2028 年以降は、`apps/api/db/seeds/020_holidays.rb` に追加して、`bin/rails db:seed` を実行する。登録が切れた年は、土日だけで営業日を判定する。
- 仕訳の持ち主は、トークンのユーザーで決まる。ユーザー登録の画面はない。ユーザーを増やすときは、seed かコンソールで作る。

## ローカルで本番用イメージを確認する

本番用イメージが動くことを、Vagrant の Docker で確認する手順。開発用の DB コンテナ（`docker-compose` の `db`）を使い、確認用の DB（`app_production`）を作って、最後に消す。開発用の DB には触らない。

```
docker build -t zentoo-api apps/api
docker build -t zentoo-web apps/web
docker-compose -f docker-compose/docker-compose.yaml up -d db

docker run -d --name zentoo-api-prod --network docker-compose_backend -p 53100:3000 \
  -e SECRET_KEY_BASE=$(openssl rand -hex 64) -e JWT_SECRET_KEY=$(openssl rand -hex 32) \
  -e DB_HOST=db -e DB_PORT=5432 -e DB_USER=postgres -e DB_PASSWORD=mysecret_password \
  -e SEED_USER_PASSWORD=prod-test-password zentoo-api

docker run -d --name zentoo-web-prod --network docker-compose_backend -p 53101:3000 \
  -e RAILS_API_URL=http://zentoo-api-prod:3000 zentoo-web
```

起動に数秒かかる。次の結果になれば成功。

```
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:53100/up      # 200
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:53101/login   # 200
curl -s -X POST http://localhost:53100/login -H "Content-Type: application/json" \
  -d '{"name":"masa","password":"prod-test-password"}'                  # token を含む JSON
curl -s -i -X POST http://localhost:53101/api/login -H "Content-Type: application/json" \
  -H "Origin: http://localhost:53101" \
  -d '{"name":"masa","password":"prod-test-password"}' | head -20       # 200 と set-cookie: token=...
```

失敗したときは `docker logs zentoo-api-prod` を見る。後片付け:

```
docker rm -f zentoo-api-prod zentoo-web-prod
docker exec docker-compose-db-1 psql -U postgres -c "DROP DATABASE app_production"
```

## 置き場所ごとの設定

VPS・ドメイン・イメージ置き場の準備が済んでから書く。

- Kamal の設定（`config/deploy.yml`）: Rails と Next.js の 2 つのサービス、公開するのは Next.js だけ
- PostgreSQL の運用（VPS 上のコンテナ）
- 日次バックアップ（別の場所へ保管）と、復元の確認
- PaaS へ移すときの対応表
