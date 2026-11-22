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
  - アシスタントはファイルを編集し、ローカルでコミットする。コミットの末尾に、作業したモデルの `Co-Authored-By` を付ける。
- Mac には node / npm / docker がない。Docker は Vagrant の中で動く。

## 現在の状態

- **M0〜M12 は完了**（M5・M6 は 2026-11-20、M7〜M9 は 2026-11-21、M10〜M12 は 2026-11-22 に完了。M12 は「お買い物の明細にタグを付けて、目的ごとに集計できる」）。
- 追加で完了したもの: 開始負債の登録、ダミー費用科目 `root` の廃止（親なし = トップレベル）。
- 本番: Kamal でデプロイ（手順は `docs/deployment.md` の「さくらの VPS + Kamal」）。日次バックアップは VPS の cron で日本時間 4 時に `ops/backup_postgres.sh`、Google Drive に rclone の crypt で暗号化して保管。crypt のパスワード 2 つと masa のパスワードは、ユーザーがパスワード管理ツールに保管。`rclone.conf` は保管も表示もしない。
- 仕訳は全種類で削除でき（DB から完全に消す。カード払いは引き落とし仕訳も一緒に消える）、お買い物の仕訳は修正できる（作り直すので ID が変わる）。それ以外の仕訳は、削除して登録し直す。
- 引き落とし仕訳は、日付だけを手で変えられる（`direct_debit_journals.payment_date_overridden` が true になる）。元のお買い物を修正しても、同じカード 1 枚での支払いのままで、買った日より前にならなければ、変えた日を引き継ぐ。
- 口座・カード（引き落とし設定ごと）・費用科目は、管理画面 `/accounts` から追加・変更・削除できる。仕訳で使っている科目は名前（とカードの設定）だけ変えられ、削除できない。費用科目は共通科目（`user_id IS NULL`）で親子の 2 階層。管理画面の使い勝手（欄の折り畳み、口座の絞り込み）は `docs/milestones.md` の「後回し」。
- 預金口座の通帳（`/bank-account-ledgers`）で、繰越から積み上げた残高と、未来の引き落とし予定、残高の不足が見られる。カードの引き落としは同じ日・同じカードの分を 1 行にまとめる（DB 関数 `get_bank_account_ledger`）。
- 収入は「収入登録」（`/income-journals`）で登録・修正できる（借方: 入金先の口座、貸方: 収益科目）。収益科目（`revenue_accounts`）は費用科目と同じく共通・親子 2 階層で、管理画面から管理する。月次の画面は「月次の収支」（収入・支出・収支）。
- 引き出し・預け入れ・口座間の振替・電子マネーへのチャージは「振替」（`/transfer-journals`）で登録・修正できる。カードからのチャージは引き落とし仕訳を自動で作る。Web の「現金の預け入れ」画面は振替にまとめた（Rails の `POST /cash-deposit-journals` は残している）。
- お買い物の明細にタグ（目的）を付けられる（`tags` はユーザーごと、明細とは多対多の `debit_tags`）。画面は明細ごとに 1 つで、お買い物登録でその場で作る。「タグの集計」（`/tag-reports`）で 1 年分を月ごとに見られる（DB 関数 `get_tag_monthly_totals`・`get_tag_items`）。
- **次のマイルストーンは未決定**。「次のマイルストーンの候補」から選ぶ。
- イメージは VPS の上でビルドする（`builder.remote`）。Vagrant は arm64 で、QEMU では Next.js のビルドが落ちるため。Kamal 2.12.0 は VPS でビルドするとき ghcr.io にログインしないので、Vagrant で `kamal registry login` してログイン情報を `~/.zentoo-kamal-docker` に残している。
- push 済みかどうかは `git status` で確認する。

## 決めたこと

- 置き場所: 最初は **VPS 1 台 + Kamal**、いずれ **PaaS** へ。置き場所に依存させない（設定は環境変数、DB は `DATABASE_URL` または `DB_*`）。
- VPS は **さくらの VPS** にした（メモリ 2 GB、Ubuntu 24.04。パケットフィルターは 22・80・443 を許可済み）。
- 本番は **空の DB から開始**。開発データは移さない。seed の後、開始資産・開始負債を画面から登録する。
- **HTTPS とドメインが必須**（トークンの Cookie が `Secure`）。ブログのドメインのサブドメインを使う案。
- 公開するのは Next.js だけ。Rails API は外に出さない。
- 本番は DB 1 つ。Solid Cache / Queue / Cable は削除済み。`RAILS_MASTER_KEY` は使わない。
- イメージ置き場は ghcr.io（GitHub の個人アクセストークン。`write:packages` と `read:packages`）。
- 認証: JWT（HS256、15 分）。POST は `next_token`、参照 API は `X-Next-Token` ヘッダでトークンを更新する。ログインは 3 分に 10 回まで。
- 費用科目・資本科目は共通（`user_id IS NULL`）。資産・負債科目はユーザー固有。
- カード払いの引き落とし仕訳は DB のトリガーが自動で作る。開始負債は、指定した引き落とし日で作る（営業日にずらさない）。

## 残りのタスク

### 本番の運用

- 本番には実データがある。削除は元に戻せない。DB を変えるマイグレーションは、デプロイ前に VPS で手動のバックアップを取る。
- デプロイは Vagrant の `/zentoo` で `kamal deploy`（Rails）と `kamal deploy -c config/deploy_web.yml`（Next.js）。コミットしてから実行する。
- ときどき VPS の `~/backup.log` と Google Drive の日付を見る（失敗しても通知は来ない）。

### 次のマイルストーンの候補（未着手）

- 親費用科目にも仕訳できてしまう点。お買い物登録は親→子の 2 段で選ぶようにし、合う子科目が無いときのために「親のまま」も選べるようにした（2026-11-21、ユーザーの判断）。API では制限していない。

### 運用メモ・小さな課題

- 祝日データは 2027 年分まで（`apps/api/db/seeds/020_holidays.rb`）。2028 年以降は追加する。
- Rails のコンテナは 1 つだけ動かす（起動のたびにマイグレーションが走る）。
- 本番を起動する CI のチェック（`RAILS_ENV=production rails zeitwerk:check` など）、GitHub Actions の Node 20 の廃止対応は、必要になったら検討する。
- Ruby のバージョンは 3 か所でそろえる: `apps/api/.ruby-version`（CI も読む）、`apps/api/Dockerfile`、`apps/api/Dockerfile.dev`。2026-11-21 に、Brakeman 8.1.1 が 3.4.7 の脆弱性（CVE-2026-132825）を検出したため 3.4.13 に上げた。
- `bin/brakeman` は `--ensure-latest` 付き（Rails の既定）。Brakeman の新しい版が出ると、指摘が無くても CI が失敗する。`bundle update brakeman --conservative` で上げる。

## 落とし穴（過去にハマったもの）

- Rails は未来の日付のマイグレーションを拒否する。最新は `20261029065000`。次は `20261030...` 以降を使う。
- DB の `RAISE` を起こすスペックは、`transaction(requires_new: true)` で囲む。
- `apps/api/.gitignore` の ctags の行は `/tags`（直下だけ）。以前は `tags` で、`app/services/tags/` が無視されてコミットされず、手元では通るのに CI（と本番イメージ）で起動に失敗した。新しいフォルダを作ったら `git status --ignored` で漏れを確かめる。
- **本番で `db:seed` をやり直さない**（管理画面で消した口座・カードが復活する）。本番に足すデータはマイグレーションで入れる（例: 収益科目の初期値は `20261121120000_create_revenue_accounts`）。
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
