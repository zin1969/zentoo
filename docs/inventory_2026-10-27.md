# 現状棚卸し（2026-10-27）

マイルストーン策定の前提として、コード・設計書・テストの実態を洗い出した結果。
「動作確認」は未実施（後述）で、コードを読んだ範囲の事実のみを記載している。

## 1. API（apps/api）

| メソッド・パス | 認証 | 状態 | 備考 |
|---|---|---|---|
| `POST /asset-opening-journals` | JWT 必須 | 実装済み | 開始残高の登録。二重登録は 409 |
| `POST /journal-entries` | JWT 必須 | 実装済み | 仕訳入力（借方・貸方の複数行、貸借不一致は 422） |
| `GET /asset-accounts` | なし | 実装済み | マスタ一覧 |
| `GET /expense-accounts` | なし | 実装済み | マスタ一覧 |
| `GET /liability-accounts` | なし | 実装済み | マスタ一覧 |
| ログイン（トークン発行） | — | **未実装** | 下記「穴」参照 |
| 仕訳の参照・一覧 | — | **未実装** | 登録した仕訳を読む API が無い |
| 残高・集計（BS/PL） | — | **未実装** | |

- 層構成は規約どおり（controllers → forms → services → repositories → `db/functions`）。DB 関数は `create_opening_asset_balance_journal` と `insert_journal_entry` の2つ。
- 認証は `TokenAuthenticator` / `TokenManager`（JWT、リクエストごとに `next_token` を返してローテーション）まで実装済み。

## 2. Web（apps/web）

| 画面 | 状態 |
|---|---|
| `/`（トップ） | **create-next-app の初期テンプレートのまま** |
| `/asset-opening-journals`（開始残高登録） | フォーム実装済み（153行）。Route Handler・Server Action あり |
| `/journal-entries`（お買い物登録） | フォーム実装済み（423行）。貸借合計の一致チェック付き |
| ログイン画面 | **無し** |
| 仕訳一覧・残高表示 | **無し** |

- BFF の共通部品（Origin 検証 `originGuard`、`logger`、トークン Cookie、マスタ取得）は実装済み。
- `apiFetch` が2つある（`lib/api/apiFetch.ts` と `lib/rails/apiFetch.ts`）。規約は前者のみを想定しており、整理が必要。
- **テストが1件も無い**（テストツール自体が未導入）。

## 3. テスト

| 対象 | RSpec 例数 |
|---|---|
| values | 36 |
| types | 15 |
| forms | 14 |
| requests | 11 |
| session_handlers | 8 |
| services | 4 |
| repositories | 4 |
| **合計** | **92** |

- 通過状況は**未確認**。Docker デーモンが停止しており、ローカルの Ruby も 3.4.3（要求は 3.4.7）のため実行を見送った。
- CI は `bundle exec rspec` に修正済みだが、GitHub 側でまだ一度も実行されていない（未 push）。
- `apps/api/test/`（Minitest）は旧 API を呼ぶ壊れたテストが残っている。

## 4. 設計書

- OpenAPI（`design/openapi`）は `POST /asset-opening-journals` のみ。`/journal-entries` とマスタ3本は未記載。
- API 仕様書（`apps/api/docs/interfaces/rest`）は `asset_opening_journals.md` のみ。
- `outline.md` / `sprint_1_outline.md` は「開始残高の登録まで・ログインは後」のまま。実装は既にそれを超えている。

## 5. 中途半端な箇所（要点）

1. **ログインが無く、画面から実際に書き込めない。** 書き込み系 API は JWT 必須だが、最初のトークンを発行する手段がどこにも無い（`TokenManager` の呼び出しは各 controller の `next_token` 発行のみ）。Web は Cookie に `token` が無いと `Bearer ` で 401 になる。手でトークンを作って Cookie に入れない限り、2つの画面は動かない。
2. **書くだけで読めない。** 登録した仕訳や開始残高を確認する手段が無い。家計簿として「結果が見える」状態になっていない。
3. **マスタ GET が未認証で、ユーザーで絞っていない。** 現状ユーザーは1人（`masa`）なので実害は無いが、ログイン導入時に直す必要がある。
4. **トップページが空。** 機能への導線が無い。
5. **Web のテストが皆無。**
6. **未着手の機能設計メモ**（`db/` 直下）: 口座振替仕訳、現金入金仕訳、営業日計算。テーブルは `direct_debit_journals` などが存在するが、ロジックは未移植。
7. **本番デプロイ未整備。** Kamal の `deploy.yml` がテンプレのまま、本番用 `Dockerfile` が無い、Web 側のデプロイ設定が無い。

## 6. 未確認事項

- RSpec 92 例の通過状況
- 開発環境で2画面が実際に動くか（Docker 起動後に確認が必要）
