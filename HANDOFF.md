# HANDOFF

zentoo の引き継ぎメモ。作成日: 2026-10-30。詳しい手順や仕様は `docs/` を見る。このファイルは「いまどこにいて、次に何をするか」だけを書く。

## プロジェクト

複式簿記ベースのお小遣い帳。個人利用（ユーザーは 1 人、`masa`）。

- `apps/api`: Rails 8.1 API（RSpec、PL/pgSQL の DB 関数・トリガー）
- `apps/web`: Next.js 16 の BFF（React 19、Tailwind 4、TypeScript）
- PostgreSQL
- `docs/`、`design/openapi`、`db/archive`

主な文書:

- [docs/milestones.md](docs/milestones.md): マイルストーンと進捗（正）
- [docs/outline.md](docs/outline.md): 全体像
- [docs/deployment.md](docs/deployment.md): 本番の手順書
- [docs/development.md](docs/development.md): 開発の手順
- [docs/rules/rails_db_logic_coding_standards.md](docs/rules/rails_db_logic_coding_standards.md): DB ロジックの規約

## 進め方のルール

- マイルストーンは 1 つずつ。同時に複数を進めない。
- 「完了」は次の 4 つがそろったとき: API（RSpec）、Web 画面（実機確認）、仕様書（OpenAPI と `apps/api/docs/interfaces/rest`）、CI が緑。
- 役割分担:
  - ユーザーが `git_zin1969 push origin main` で push し、Docker / Vagrant のコマンドを実行して出力を貼る。
  - アシスタントはファイルを編集し、ローカルでコミットする。コミットの末尾に `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` を付ける。
- Mac には node / npm / docker がない。Docker は Vagrant の中で動く。

## 現在の状態

- **M0〜M4 は完了**。M4 完了時点で CI は全緑。
- 追加で完了したもの: 開始負債の登録、ダミー費用科目 `root` の廃止（親なし = トップレベル）。
- **M5「外から使える」を進行中**。
  - 完了: 本番用 Dockerfile（API と Web）、シークレット管理と seed の手順書（`docs/deployment.md`）。
  - 未完了: Kamal の設定、VPS・ドメイン・イメージ置き場の準備、PostgreSQL の運用とバックアップ、本番での通し確認。
- `a3a29b7`（本番手順書の追加）までコミット済み。`d068af3` より後のコミットは**未 push**の可能性がある（約 8 件）。push して api-ci / web-ci を確認すること。
- 作業ツリーはこの `HANDOFF.md` を除いてクリーン。

## 決めたこと

- 置き場所: 最初は **VPS 1 台 + Kamal**、いずれ **PaaS** へ。置き場所に依存させない（設定は環境変数、DB は `DATABASE_URL` または `DB_*`）。
- VPS は **Xserver VPS** にする（ブログで使っているため）。メモリ 2 GB 以上、Ubuntu 24.04 を想定。契約は短い期間から。
- 本番は **空の DB から開始**。開発データは移さない。seed の後、開始資産・開始負債を画面から登録する。
- **HTTPS とドメインが必須**（トークンの Cookie が `Secure`）。ブログのドメインのサブドメインを使う案。
- 公開するのは Next.js だけ。Rails API は外に出さない。
- 本番は DB 1 つ。Solid Cache / Queue / Cable は削除済み。`RAILS_MASTER_KEY` は使わない。
- イメージ置き場は ghcr.io（GitHub の個人アクセストークン。`write:packages` と `read:packages`）。
- 認証: JWT（HS256、15 分）。POST は `next_token`、参照 API は `X-Next-Token` ヘッダでトークンを更新する。ログインは 3 分に 10 回まで。
- 費用科目・資本科目は共通（`user_id IS NULL`）。資産・負債科目はユーザー固有。
- カード払いの引き落とし仕訳は DB のトリガーが自動で作る。開始負債は、指定した引き落とし日で作る（営業日にずらさない）。

## 残りのタスク

### M5（次にやること）

ユーザーが VPS・ドメイン・レジストリを用意したら、次の情報を受け取る（秘密は貼らない）:

1. VPS の IP アドレス
2. 使うドメイン（サブドメイン）
3. GitHub のユーザー名（ghcr.io のイメージ名に使う）

その後:

- [ ] VPS の初期設定の手順書（一般ユーザー、ssh は公開鍵のみ、root とパスワードでのログインを無効化、ファイアウォール、自動更新）。Xserver VPS はパケットフィルターが別にあるので、22・80・443 を許可する。
- [ ] `apps/api/config/deploy.yml` を Kamal 用に書き直す（いまは Rails 生成のままで、`SOLID_QUEUE_IN_PUMA` や `localhost:5555` が残っている）。Rails と Next.js の 2 サービス、PostgreSQL は VPS 上のコンテナ、Rails は非公開。
- [ ] PostgreSQL の日次バックアップ（VPS の外に保管）と、復元の確認。
- [ ] 本番でスマホから M1〜M4 を通し確認（チェックリストは `docs/deployment.md`）。
- [ ] `docs/deployment.md` の「置き場所ごとの設定」を埋める。`docs/milestones.md` の M5 を更新する。

### M5 のあと（候補。未着手）

- **M6 案: 銀行の引き落とし予定を日ごとに見る**。`GET /scheduled-direct-debits` と画面で、未来の引き落とし仕訳を日付・銀行・カード別に出す。未決の 3 点（いずれも推奨は先頭）: 引き落とし後の残高と不足の警告を出す／カード単位の明細まで／対象はカード払いのみ。
- 仕訳の修正・削除（いまはできない。開始残高の登録は金額と日付を確認してから行う）。
- 収入の登録（収益科目に未対応）、現金の引き出し、口座・科目の管理画面、振替。
- 親費用科目にも仕訳できてしまう点（葉の科目だけに制限するか、要相談）。

### 運用メモ・小さな課題

- 祝日データは 2027 年分まで（`apps/api/db/seeds/020_holidays.rb`）。2028 年以降は追加する。
- Rails のコンテナは 1 つだけ動かす（起動のたびにマイグレーションが走る）。
- 本番を起動する CI のチェック（`RAILS_ENV=production rails zeitwerk:check` など）、GitHub Actions の Node 20 の廃止対応、Ruby 3.4.7 のそろえ方は、必要になったら検討する。

## 落とし穴（過去にハマったもの）

- Rails は未来の日付のマイグレーションを拒否する。最新は `20261029065000`。次は `20261030...` 以降を使う。
- DB の `RAISE` を起こすスペックは、`transaction(requires_new: true)` で囲む。
- `db:prepare` は DB を**新しく作ったときだけ** seed する。entrypoint が、パスワードを持つユーザーがいなければ seed を再実行して補っている。
- 本番は全 gem のモデルを eager load する。使っていない gem（Solid*）が余計な DB を要求する。
- `db:migrate` は開発 DB から `structure.sql` を書き直す。差分を確認してからコミットする。
- DB 関数の `CREATE OR REPLACE` を使うマイグレーションは不可逆（`down` で `IrreversibleMigration`）。規約は `docs/rules/rails_db_logic_coding_standards.md`。
- macOS の BSD `sed` は置換に `\n` を使えない。Edit ツールを使う。
- `find /` は実行しない。

## 開発環境のコマンド

```bash
docker-compose -f docker-compose/docker-compose.yaml run --rm [--no-deps] [-e CI=true] <api|next> ...
```

- ポート: web 53001、api 53000、db 55432。
- ネットワーク `docker-compose_backend`、DB コンテナ `docker-compose-db-1`。
- 本番用イメージのローカル確認は `docs/deployment.md` の「ローカルで本番用イメージを確認する」。
