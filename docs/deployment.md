# 本番環境の手順

本番で動かすための設定と手順。開発の手順は [development.md](development.md)、現在地は [milestones.md](milestones.md) を参照。

前半は、置き場所（VPS + Kamal、将来の PaaS）に依存しない部分を書く。Kamal の設定やバックアップなどは「置き場所ごとの設定」に書く。

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

### Xserver VPS + Kamal

構成は VPS 1 台。リポジトリは公開なので、IP アドレスと秘密情報はリポジトリに書かず、環境変数で渡す。

```text
kamal-proxy (80, 443) ──▶ zentoo-web ──▶ zentoo-api ──▶ zentoo-api-db
                          公開            kamal ネットワークの中だけ
```

| 設定ファイル | 内容 |
|--------------|------|
| `apps/api/config/deploy.yml` | Rails API（proxy なし）と PostgreSQL（accessory） |
| `apps/api/config/deploy_web.yml` | Next.js（proxy、HTTPS） |
| `apps/api/.kamal/secrets` | 秘密情報の受け渡し（値は環境変数から） |

#### 1. VPS の初期設定

Ubuntu 24.04、メモリ 2 GB 以上で作る。Xserver VPS の管理画面のパケットフィルターで、**22、80、443 だけ**を許可する。

root でログインして、一般ユーザーを作り、Docker を入れる。`<公開鍵>` は Vagrant で使う ssh の公開鍵に置き換える。

```
adduser --disabled-password --gecos "" deploy
usermod -aG sudo deploy
mkdir -p /home/deploy/.ssh
echo "<公開鍵>" > /home/deploy/.ssh/authorized_keys
chown -R deploy:deploy /home/deploy/.ssh
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys
passwd deploy

apt-get update && apt-get -y upgrade
apt-get install -y docker.io unattended-upgrades rclone ufw
usermod -aG docker deploy
dpkg-reconfigure -f noninteractive unattended-upgrades

ufw allow 22/tcp && ufw allow 80/tcp && ufw allow 443/tcp
ufw --force enable
```

**今の接続を切らずに**、別のターミナルで `ssh deploy@<IP>` と `sudo -v` が通ることを確認してから、ssh を公開鍵のみにする。

```
cat > /etc/ssh/sshd_config.d/99-hardening.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF
sshd -t && systemctl reload ssh
```

Docker が公開するポートは ufw を通らない。外に出るのは kamal-proxy の 80 と 443 だけで、DB と Rails はポートを公開しない設定にしてある。パケットフィルターも合わせて二重に守る。

#### 2. ドメインとイメージ置き場

- ドメイン（サブドメイン）の A レコードを、VPS の IP アドレスに向ける。証明書の取得に必要なので、デプロイの前に済ませる。
- GitHub で、`write:packages` と `read:packages` を持つ個人アクセストークン（classic）を作る。

#### 3. デプロイの準備（Vagrant）

Kamal は、公式のコンテナイメージで Vagrant から実行する。Ruby は要らない。

秘密情報は、リポジトリの外（`~/.zentoo-kamal.env`）に置く。Vagrant と共有しているリポジトリのフォルダには置かない。値はパスワード管理ツールにも保管する。**値に引用符を付けない**（`--env-file` はそのまま読む）。

```
touch ~/.zentoo-kamal.env
chmod 600 ~/.zentoo-kamal.env
```

```
ZENTOO_HOST=<VPS の IP アドレス>
ZENTOO_DOMAIN=<サブドメイン>
ZENTOO_REGISTRY_USER=<GitHub のユーザー名>
KAMAL_REGISTRY_PASSWORD=<個人アクセストークン>
SECRET_KEY_BASE=<openssl rand -hex 64 の結果>
JWT_SECRET_KEY=<openssl rand -hex 32 の結果>
DB_PASSWORD=<openssl rand -hex 32 の結果>
SEED_USER_PASSWORD=<masa のパスワード>
```

次の関数を Vagrant の `~/.bashrc` に足して、読み込み直す。

```
kamal() {
  docker run -it --rm \
    --env-file "$HOME/.zentoo-kamal.env" \
    -v "$(git rev-parse --show-toplevel):/workdir" \
    -w /workdir/apps/api \
    -v "$SSH_AUTH_SOCK:/ssh-agent" -e SSH_AUTH_SOCK=/ssh-agent \
    -v /var/run/docker.sock:/var/run/docker.sock \
    ghcr.io/basecamp/kamal:v2.12.0 "$@"
}
```

ssh の鍵を ssh-agent に登録し、設定が読めることを確認する。

```
eval "$(ssh-agent -s)" && ssh-add
kamal config
kamal config -c config/deploy_web.yml
```

Xserver VPS は amd64。Vagrant が arm64（`uname -m` が `aarch64`）のときは、amd64 のビルドに必要なエミュレーションを入れる。

```
docker run --privileged --rm tonistiigi/binfmt --install amd64
```

#### 4. 初回デプロイ

Rails → Next.js の順に実行する（Next.js は Rails の名前で接続するため）。`setup` は、PostgreSQL の起動、イメージのビルド、アプリの起動までを行う。

```
kamal setup
kamal setup -c config/deploy_web.yml
```

`https://<サブドメイン>/login` が開いて、`masa` でログインできたら、`~/.zentoo-kamal.env` の `SEED_USER_PASSWORD` の行を消して、Rails をデプロイし直す。サーバーにパスワードを残さないため。

```
kamal deploy
```

そのあと、「開始残高の登録」と「動作確認のチェックリスト」に進む。

#### 5. 2 回目以降のデプロイ

コミットしてから、変えた方だけ実行する。Rails は git のコミットからビルドするので、**コミットしていない変更は入らない**。Next.js は作業ツリーからビルドするので、**コミットしていない変更も入る**。作業ツリーをきれいにしてから実行する。

```
kamal deploy
kamal deploy -c config/deploy_web.yml
```

Rails の切り替えの間は、新旧のコンテナが短い時間だけ並んで動く。マイグレーションは新しいコンテナの起動時に走るので、古いコードが動かなくなるマイグレーションを入れるときは注意する。

ログと、ひと通りの確認:

```
kamal logs
kamal logs -c config/deploy_web.yml
kamal accessory logs db
```

#### 6. 日次バックアップ

`ops/backup_postgres.sh` を VPS の cron で毎日実行し、ダンプを rclone で VPS の外に保管する。ローカルに 7 日、外に 30 日残す。**中身は家計のデータなので、保管先では rclone の `crypt` で暗号化する**。

Vagrant からスクリプトを送り、VPS の `deploy` ユーザーで rclone の保管先を設定する（保管先は rclone が対応するものなら何でもよい。名前は `zentoo-backup` とする）。

```
scp ops/backup_postgres.sh deploy@<IP>:~/backup_postgres.sh
```

```
chmod 700 ~/backup_postgres.sh
rclone config
BACKUP_REMOTE=zentoo-backup:zentoo ~/backup_postgres.sh
rclone ls zentoo-backup:zentoo
```

動いたら、`crontab -e` で登録する（サーバーの時刻は UTC。次は日本時間の 4 時）。

```
0 19 * * * BACKUP_REMOTE=zentoo-backup:zentoo $HOME/backup_postgres.sh >> $HOME/backup.log 2>&1
```

失敗しても通知は来ない。ときどき `~/backup.log` と保管先の日付を見る。

**rclone の設定（`~/.config/rclone/rclone.conf`）は、パスワード管理ツールにも保管する**。VPS が消えると、これがないとバックアップを復号できない。

#### 7. 復元の確認

保管先のダンプを取り戻して、別の DB に復元する。本番の DB には触らない。初回と、ときどき実施する。`<ダンプ>` は `rclone ls` で確認したファイル名。

```
rclone copy zentoo-backup:zentoo/<ダンプ> /tmp/restore
docker exec zentoo-api-db createdb -U zentoo restore_check
docker exec -i zentoo-api-db pg_restore -U zentoo -d restore_check --no-owner < /tmp/restore/<ダンプ>
docker exec zentoo-api-db psql -U zentoo -d restore_check -c "SELECT (SELECT count(*) FROM users) AS users, (SELECT count(*) FROM journals) AS journals"
docker exec zentoo-api-db psql -U zentoo -d app_production -c "SELECT (SELECT count(*) FROM users) AS users, (SELECT count(*) FROM journals) AS journals"
docker exec zentoo-api-db dropdb -U zentoo restore_check
rm -rf /tmp/restore
```

2 つの件数が（ダンプのあとの登録分を除いて）合えば成功。本番を復元するときは、アプリを止めて（`kamal app stop`）から `pg_restore --clean --if-exists -d app_production` を使い、`kamal app boot` で戻す。

### PaaS へ移すとき

| VPS + Kamal | PaaS |
|-------------|------|
| `apps/api/Dockerfile`、`apps/web/Dockerfile` | そのまま使う |
| `DB_HOST` など | マネージド DB の `DATABASE_URL` |
| `RAILS_API_URL=http://zentoo-api:3000` | PaaS の内部ネットワークの URL |
| kamal-proxy の HTTPS | PaaS の HTTPS。`Host` がそのまま Next.js に届くことを確認する |
| `ops/backup_postgres.sh` | ダンプを取って移す。その後は PaaS のバックアップ |
