# プロダクト概要

複式簿記の考え方を取り入れたお小遣い帳システム

# 利用者

若手社会人

# 進め方

マイルストーン単位で進める。現在地と今後の予定は [milestones.md](milestones.md)、実装の現状は [inventory_2026-10-27.md](inventory_2026-10-27.md) を参照。

# 機能の大枠

- 資産の開始残高を登録できる
- 日々の仕訳（お買い物）を登録できる
- 登録した仕訳・残高・収支を確認できる（未実装）
- ログイン（API・画面とも実装済み。ユーザー登録画面は作らない。開発用ユーザーは seeds で作成）

# 画面 / API

- Web画面（Next.js、Browser 向けは BFF として提供）
- API（Rails）
- PL/pgSQL function（DB ロジック）

# 技術スタック

- API : Rails 8
- Front : Next.js / React
- DB : PostgreSQL 17
- 開発環境 : Docker Compose（Vagrant 上の Debian）
- デプロイ : Kamal（未整備）
- CI : GitHub Actions

# コーディング規約

[rules/](rules/) を参照。
