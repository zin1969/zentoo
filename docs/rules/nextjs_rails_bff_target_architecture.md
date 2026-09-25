# Next.js + Rails BFF 将来アーキテクチャ設計メモ

> これは現在の**コーディング規約ではない**。ソロ開発・単一 VPS（Kamal）デプロイという現状の規模には合わないため [nextjs_rails_bff_coding_standards.md](nextjs_rails_bff_coding_standards.md) から切り出した、チーム・インフラが拡大した際の設計メモである。今すぐの適用は求めない。各節の見出しは切り出し元の章番号に対応する。導入する際は、その時点の規約本文にこの内容を戻す。

---

## システム構成（元 2.1）

```text
Internet
   │
   ▼
CloudFront / WAF
   │
   ▼
Next.js
(BFF / Browser API)
   │
   │ Private / Server-to-Server
   ▼
Rails API
(Business API)
   │
   ▼
Aurora / PostgreSQL
```

---

## サーバー間通信の多層防御（元 2.3）

7.2 の JWT によるユーザー認証は、あくまで「誰のリクエストか」を Rails 側で識別するための仕組みであり、それ単体を Next.js ↔ Rails 間のネットワークレベルのアクセス制御の代わりにはしない。インフラ構成に応じて、以下のようなネットワークレベルの防御を併用する。

- Rails をプライベートサブネット等に配置し、インターネットから直接到達できないようにする
- Next.js ↔ Rails 間の通信を VPC 内限定など、許可されたネットワーク経路に制限する
- 必要に応じて mTLS 等、通信経路自体の相互認証を導入する

JWT 認証（アプリケーションレベル）とネットワーク的な到達性の制限（インフラレベル）は、どちらか一方で足りるものではなく、両方を組み合わせる。

---

## Rails API変更時の後方互換性とデプロイ順序（元 21）

Next.js と Rails は個別にデプロイされる。既存 API を変更するときは、両者のデプロイタイミングにズレがあっても動作し続けるようにする。

### Expand/Contract（拡張・収縮）方式

既存 API の変更は、パスにバージョンを持たせず、以下の3段階で進める。

```text
1. Expand（拡張）
   Rails API に新しいフィールド／新しい挙動を「追加」する。
   既存フィールド・既存挙動は残したまま、後方互換を維持する。
        ↓
2. Migrate（移行）
   Next.js BFF・Browser を新しい仕様に追従させる。
   この間、Rails は新旧両方のリクエスト・レスポンスに対応し続ける。
        ↓
3. Contract（収縮）
   Next.js 側が新しい仕様に完全移行したことを確認した後、
   Rails 側の旧フィールド・旧挙動を削除する。
```

既存フィールドの削除・型変更・必須化、レスポンス構造の変更などの破壊的変更は、Expand フェーズを経ずに一度に行わない。

### デプロイ順序

Expand/Contract の各フェーズで、デプロイ順序は次の通りとする。

```text
Expand:   Rails を先にデプロイ → 動作確認後、Next.js をデプロイ
Contract: Next.js を先にデプロイ（新仕様への移行完了）→ 動作確認後、Rails の旧実装を削除してデプロイ
```

Next.js と Rails を同時にデプロイしない。どちらか一方が先にリリースされた状態でも、他方が壊れないことをデプロイ前に確認する。

### レビュー時の確認事項

既存 API を変更するプルリクエストでは、以下を確認する。

- [ ] 既存フィールドの削除・型変更・必須化など、破壊的変更を一度に行っていない
- [ ] Expand フェーズでは、旧フィールド・旧挙動が残ったままになっている
- [ ] Contract フェーズは、Next.js 側の移行が完了したことを確認してから行っている
- [ ] 変更内容に対してデプロイ順序（Expand: Rails→Next.js／Contract: Next.js→Rails）が正しい

---

## ファイルアップロード・大容量ペイロード（元 23）

現時点でファイルアップロードを伴う API は存在しないが、将来追加する場合は以下を標準とする。

### アップロード方式

Browser → Next.js → Rails という既存の BFF 境界を維持し、Next.js をプロキシとして経由させる。

```text
Browser
   │ multipart/form-data
   ▼
Next.js (Route Handler)
   │ Server-to-Server
   ▼
Rails API
   │
   ▼
Active Storage / オブジェクトストレージ
```

- Browser から直接ストレージ（S3 等）にアップロードする Direct Upload 方式（署名付き URL を Browser に渡す方式）は採用しない。Browser に外部ストレージの URL を扱わせることになり、「Browser に Rails API の内部 URL を公開しない」「Browser が利用する API は原則として Next.js 側に提供する」という原則と相容れないため。
- Next.js は受け取ったファイルを Rails にそのまま転送する。画像変換等の重い処理は Rails 側（Active Storage / image processing）で行い、Next.js では行わない。

### サイズ制限

- Next.js Route Handler・Rails 双方で許容する最大リクエストサイズを明示的に設定し、無制限を許容しない。
- 実際の上限値はアップロード対象（画像、PDF 等）に応じて、機能追加時に決定する。
