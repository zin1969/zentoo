# HANDOFF

zentoo の引き継ぎメモ。作成日: 2026-10-30、最終更新: 2026-11-28。詳しい手順や仕様は `docs/` を見る。このファイルは「いまどこにいて、次に何をするか」だけを書く。

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
- Web を変えたら、`npx tsc --noEmit` と `npm run lint` の両方を案内する。Rails を変えたら、RSpec と一緒に `bin/rubocop` と `bin/brakeman --no-pager` も案内する（CI が実行する。`docs/development.md` の「テストと CI 相当のチェック」）。
- 「完了」は次の 4 つがそろったとき: API（RSpec）、Web 画面（実機確認）、仕様書（OpenAPI と `apps/api/docs/interfaces/rest`）、CI が緑。
- 役割分担:
  - ユーザーが `git_zin1969 push origin main` で push し、Docker / Vagrant のコマンドを実行して出力を貼る。
  - アシスタントはファイルを編集し、ローカルでコミットする。コミットの末尾に、作業したモデルの `Co-Authored-By` を付ける。コミットメッセージは英語、ユーザーへの返答は日本語。
- Mac には node / npm / docker がない。Docker は Vagrant の中で動く。

## 現在の状態

- **M0〜M19 は完了**（M5・M6 は 2026-11-20、M7〜M9 は 2026-11-21、M10〜M12 と改善「外税のレシート」は 2026-11-22、M13 は 2026-11-25、M14 は 2026-11-26、M15・M16 は 2026-11-27、M17〜M19 は 2026-11-28 に完了）。
- 追加で完了したもの: 開始負債の登録、ダミー費用科目 `root` の廃止（親なし = トップレベル）。
- 本番: Kamal でデプロイ（手順は `docs/deployment.md` の「さくらの VPS + Kamal」）。日次バックアップは VPS の cron で日本時間 4 時に `ops/backup_postgres.sh`、Google Drive に rclone の crypt で暗号化して保管。crypt のパスワード 2 つと masa のパスワードは、ユーザーがパスワード管理ツールに保管。`rclone.conf` は保管も表示もしない。
- 仕訳は全種類で削除でき（DB から完全に消す。カード払いは引き落とし仕訳も一緒に消える）、お買い物・収入・振替・精算の仕訳は修正できる（作り直すので ID が変わる）。それ以外の仕訳（開始残高・株の売買など）は、削除して登録し直す。
- 引き落とし仕訳は、日付だけを手で変えられる（`direct_debit_journals.payment_date_overridden` が true になる）。元のお買い物を修正しても、同じカード 1 枚での支払いのままで、買った日より前にならなければ、変えた日を引き継ぐ。
- 口座・カード（引き落とし設定ごと）・費用科目・収益科目は、管理画面 `/accounts` から追加・変更・削除できる（タグは名前の変更と削除だけ）。仕訳か決まった収支で使っている科目は名前（とカードの設定）だけ変えられ、削除できない（`Accounts::AccountUsage.used`）。費用科目は共通科目（`user_id IS NULL`）で親子の 2 階層。管理画面の使い勝手（欄の折り畳み、口座の絞り込み）は `docs/milestones.md` の「後回し」。
- 預金口座の通帳（`/bank-account-ledgers`）で、繰越から積み上げた残高と、未来の引き落とし予定、残高の不足が見られる。カードの引き落としは同じ日・同じカードの分を 1 行にまとめる（DB 関数 `get_bank_account_ledger`）。
- 収入は「収入登録」（`/income-journals`）で登録・修正できる（借方: 入金先の口座、貸方: 収益科目）。収益科目（`revenue_accounts`）は費用科目と同じく共通・親子 2 階層で、管理画面から管理する。月次の画面は「月次の収支」（収入・支出・収支）。
- 引き出し・預け入れ・口座間の振替・電子マネーへのチャージは「振替」（`/transfer-journals`）で登録・修正できる。カードからのチャージは引き落とし仕訳を自動で作る。Web の「現金の預け入れ」画面は振替にまとめた（Rails の `POST /cash-deposit-journals` は残している）。
- お買い物の明細にタグ（目的）を付けられる（`tags` はユーザーごと、明細とは多対多の `debit_tags`）。画面は明細ごとに 1 つで、お買い物登録でその場で作る。「タグの集計」（`/tag-reports`）で 1 年分を月ごとに見られる（DB 関数 `get_tag_monthly_totals`・`get_tag_items`）。
- お買い物登録で、外税のレシートを「税抜（外税）」に切り替えて、明細ごとの税抜の金額と税率（10% / 8% / その他の数値）で登録できる（2026-11-22 完了）。消費税は税率ごとの合計から切り捨てで計算し、手で直せる。明細の `amount` は税込のままで、表示のために `tax_rate`・`tax_excluded_amount` を保存する（計算は `apps/web/src/lib/journals/consumptionTax.ts`）。修正では税抜の状態で開く。
- 決まった収支（家賃・サブスク・給料など）を設定し、回ごとに確かめてから登録できる（M13、2026-11-25 完了）。画面は「決まった収支」（`/recurring-entries`、設定は `/recurring-entries/settings`）。コードと仕様書の名前は `recurring_entries`（`recurring_entries` と回の記録 `recurring_entry_occurrences`）。周期は月単位（N ヶ月ごとの D 日、31 は月末）と週単位（N 週ごとの何曜日）で、予定日は DB 関数 `get_recurring_dates`。自動では登録しない。仕訳を修正（作り直し）しても回の記録は付いたまま。決まった振替（M17）も同じ仕組み。
- 仕訳一覧の「コピー」で、お買い物・収入・振替を同じ内容（日付は今日）で新しく登録できる（M14、2026-11-26 完了）。画面は `/journal-entries/{id}/copy` など。修正画面の読み込みとフォームを `copy` で使い回している（Next.js だけ。API・DB は変えていない）。
- 仕訳一覧で、キーワード（店舗名・摘要・品目）、科目・口座・カード、タグから仕訳を探せる（M15、2026-11-27 完了）。API は `GET /journals` の `q`・`element_type` と `account_id`（組で指定。費用・収益科目は親を選ぶと子科目も含む）・`tag_id`。条件は期間と AND で、画面の「すべての期間」で期間を外せる。DB は変えていない。検索の条件は画面の中だけで持つので、修正画面などから戻ると初期値（今月・条件なし）に戻る。
- 資産の口座に種別「証券口座（預り金）」（`securities` = 4）と「投資」（`investment` = 5。iDeCo・積立 NISA・株式など）がある（M16、2026-11-27 完了）。ユーザーの毎月の流れは、銀行 → 証券口座 → 積立 NISA と、銀行 → iDeCo で、どれも振替で登録する。振替は出す元の口座の種別を貸方の `payment_method_type` に入れるので、資産の貸方の制約は 1〜5。お買い物の支払い方法は現金・電子マネーだけ、決まった収支の支払い方法は現金・預金・電子マネーだけ（Web で絞っている。API では制限していない）。
- 決まった収支で振替も設定・登録できる（M17、2026-11-28 完了）。`recurring_entries.kind` = 3（1 = 支出、2 = 収入）で、列は増やしていない（借方 `debit_account_id` が入金先の口座、貸方が出金元の口座かカード）。登録は振替と同じ DB 関数 `create_transfer_journal`（カードからのチャージは電子マネーだけで、引き落とし仕訳も自動）。摘要は `store_name`、空なら名前。振替の修正（`replace_transfer_journal`）でも回の記録を引き継ぐ。
- 現物株を銘柄ごとに、株数と取得額で管理できる（M18、2026-11-28 完了）。銘柄は種別「投資」の口座（取得額 = 口座の残高）で、明細の `shares`（資産の明細だけ）で株数を持つ。今持っている株は「開始資産登録」で株数と平均取得単価から登録する（`POST /asset-opening-journals` の `shares`、DB 関数 `create_opening_stock_balance_journal`）。売買は「株の売買」（`/stock-trades`、DB 関数 `create_stock_buy_journal`・`create_stock_sell_journal`）、一覧は「保有株」（`/stock-holdings`、`get_stock_holdings`）。相手は証券口座（預り金）だけ。買いの手数料は取得額に含め、売りは移動平均の取得額を減らし、差額を「株式売却益」（収益）か「株式売却損」（費用）に入れる。この 2 つは名前で探すので、名前を変えると売りが 422 になる。配当は収入登録で、入金先を証券口座、科目を「配当金」にして手取りの額で登録する。後の日付の売りがある銘柄には、前の日付で登録できない（移動平均が合わなくなるため。後の売りを消して日付の順に登録し直す）。売買は修正できず、株の買いは振替と同じ形でも振替として直せない。仕様は `apps/api/docs/interfaces/rest/stock_trades.md`・`stock_holdings.md`。
- 立て替えた分を精算できる（M19、2026-11-28 完了）。立替金は資産の口座の種別 6 で、相手ごとに作る（友だち・「立替金 会社」）。お買い物登録の「立て替え」の欄で自分以外の分を立替金の明細（借方の資産）にする。全額の立て替え（費用の明細 0 件）も登録・修正できる（`replace_journal_entry` が費用か本人の立替金の明細を許す）。会社の交通費は、仕事で乗った日に振替（PASMO → 立替金 会社）で付ける。振替では立替金から出せない（`receivable_requires_settlement`）。返してもらった分は「立替金の精算」（`/settlement-journals`、DB 関数 `create_settlement_journal`・`replace_settlement_journal`）で登録し、差額は少なければ費用、多ければ収益、受け取りなしは全額費用。精算の仕訳は貸方に立替金（`payment_method_type` = 6）があるもので、お買い物・振替の修正では直せない。仕訳一覧で科目を指定すると、全ページ分の借方・貸方の合計（`account_totals`）が出る（月末に精算書と突き合わせる）。借方の明細には口座の種別 `asset_type` が付く。仕様は `apps/api/docs/interfaces/rest/settlement_journals.md`。
- **次は M20「予算と実績」**（未着手、2026-11-28 ユーザーの判断）。予算は費用科目かタグごとに、週（月曜始まり）・月（毎月同じ額か月ごとの額）・年（暦年）で持つ。科目の予算には除くタグ（食費からアルコールを外す）を付けられる。繰り越しと額の履歴は持たない。方針とタスクは `docs/milestones.md`。
- PayPay は、カード（負債）と電子マネー（資産）の 2 つを本番で別々に登録する（ユーザーの運用）。
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
- 費用科目・収益科目・資本科目は共通（`user_id IS NULL`）。資産・負債科目とタグ・決まった収支はユーザー固有。
- 親の費用科目にも仕訳できる。お買い物登録は親→子の 2 段で選び、合う子科目が無いときのために「親のまま」も選べる（2026-11-21、ユーザーの判断）。API では制限していない。
- カード払いの引き落とし仕訳は DB のトリガーが自動で作る。開始負債は、指定した引き落とし日で作る（営業日にずらさない）。

## 残りのタスク

### 本番の運用

- 本番には実データがある。削除は元に戻せない。DB を変えるマイグレーションは、デプロイ前に VPS で手動のバックアップを取る。
- デプロイは `vagrant ssh` で入った Vagrant の `/zentoo` で `kamal deploy`（Rails）と `kamal deploy -c config/deploy_web.yml`（Next.js）。Mac には `kamal` が無い。コミット・push してから実行する。変えた方だけでよい（Next.js だけの変更なら Rails は不要）。
- ときどき VPS の `~/backup.log` と Google Drive の日付を見る（失敗しても通知は来ない）。

### 次の候補（未着手。ユーザーに選んでもらう）

- iDeCo・積立 NISA・株の評価額（ある日時点の評価額を入力して損益を見る。ユーザーが「後回しでよい」と判断）
- 支出の推移グラフ（1 年分の収入・支出・科目ごとの支出を月ごとのグラフで）
- `docs/milestones.md` の「後回し」（管理画面の使い勝手、検索の条件を URL に残す など）

### 運用メモ・小さな課題

- 祝日データは 2027 年分まで（`apps/api/db/seeds/020_holidays.rb`）。2028 年以降は追加する。
- Rails のコンテナは 1 つだけ動かす（起動のたびにマイグレーションが走る）。
- 本番を起動する CI のチェック（`RAILS_ENV=production rails zeitwerk:check` など）、GitHub Actions の Node 20 の廃止対応は、必要になったら検討する。
- Ruby のバージョンは 3 か所でそろえる: `apps/api/.ruby-version`（CI も読む）、`apps/api/Dockerfile`、`apps/api/Dockerfile.dev`。2026-11-21 に、Brakeman 8.1.1 が 3.4.7 の脆弱性（CVE-2026-132825）を検出したため 3.4.13 に上げた。
- Node.js のバージョンは 3 か所でそろえる: `apps/web/Dockerfile`（`NODE_VERSION`）、`apps/web/Dockerfile.dev`、`.github/workflows/web-ci.yml`（`node-version`）。2026-11-28 に、開発用だけ 20 だったのを 22 にそろえた。
- `bin/brakeman` は `--ensure-latest` 付き（Rails の既定）。Brakeman の新しい版が出ると、指摘が無くても CI が失敗する。`bundle update brakeman --conservative` で上げる。

## 落とし穴（過去にハマったもの）

- Rails は未来の日付のマイグレーションを拒否する。最新は `20261128140000`。次は、その日の日付（`YYYYMMDDhhmmss`）で、最新より後の番号を使う。
- DB の `RAISE` を起こすスペックは、`transaction(requires_new: true)` で囲む。
- 明細の `element_type` は独自の型（`ElementTypeType`）なので、`Debit.where(element_type: 5)` のようなハッシュの条件は `comparison of Integer with ElementType failed` で落ちる。`where("debits.element_type = ?", 5)` と SQL で書く。
- `spec/rails_helper.rb` の FactoryBot は `config.include` で入れる。素の `include` だと `create` が Object に入り、モジュールから来る `create` アクション（`TwoLevelAccountsActions`）が 404 になる（2026-11-27 に直した）。
- リクエストスペックで `travel_to` を使うときは、トークンを作るところ（最初のリクエスト）から中に入れる。トークンは 15 分で切れるので、外で作ると 401 になる。
- 仕訳の明細の `amount` は値オブジェクト（`Amount`）。スペックでは `to_i` で整数にして比べる。
- `apps/api/.gitignore` の ctags の行は `/tags`（直下だけ）。以前は `tags` で、`app/services/tags/` が無視されてコミットされず、手元では通るのに CI（と本番イメージ）で起動に失敗した。新しいフォルダを作ったら `git status --ignored` で漏れを確かめる。
- **本番で `db:seed` をやり直さない**（管理画面で消した口座・カードが復活する）。本番に足すデータはマイグレーションで入れる（例: 収益科目の初期値は `20261121120000_create_revenue_accounts`）。
- `db:prepare` は DB を**新しく作ったときだけ** seed する。entrypoint が、パスワードを持つユーザーがいなければ seed を再実行して補っている。
- 本番は全 gem のモデルを eager load する。使っていない gem（Solid*）が余計な DB を要求する。
- `db:migrate` は開発 DB から `structure.sql` を書き直す。差分を確認してからコミットする。
- DB 関数の `CREATE OR REPLACE` を使うマイグレーションは不可逆（`down` で `IrreversibleMigration`）。規約は `docs/rules/rails_db_logic_coding_standards.md`。
- macOS の BSD `sed` は置換に `\n` を使えない。Edit ツールを使う。
- `find /` は実行しない。
- `docker compose ... run --no-deps` は DB を起動しない。Vagrant を起動し直したあとは、先に `docker compose -f docker-compose/docker-compose.yaml up -d db`（または `up`）で DB を起動する。起動していないと `could not translate host name "db"` になる。

## 開発環境のコマンド

```bash
docker compose -f docker-compose/docker-compose.yaml run --rm [--no-deps] [-e CI=true] <api|next> ...
```

- ポート: web 53001、api 53000、db 55432。
- ネットワーク `docker-compose_backend`、DB コンテナ `docker-compose-db-1`。
- 本番用イメージのローカル確認は `docs/deployment.md` の「ローカルで本番用イメージを確認する」。
