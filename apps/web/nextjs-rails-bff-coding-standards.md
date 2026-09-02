# Next.js + Rails API コーディング規約

## 1. 目的

本規約は、Next.js を Frontend / BFF、Rails を Backend API として利用する Web アプリケーションにおける、API 通信・認証・CSRF 対策・責務分担・実装ルールを定める。

基本方針は以下とする。

> ブラウザから Rails API を直接呼び出さず、Next.js を BFF（Backend for Frontend）として経由する。

```text
Browser
   │
   │ HTTPS
   ▼
Next.js
   │
   │ Server-to-Server
   ▼
Rails API
   │
   ▼
PostgreSQL
```

---

## 2. 基本アーキテクチャ

### 2.1 システム構成

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

### 2.2 原則

- Browser は Rails API に直接アクセスしない。
- Browser が利用する API は原則として Next.js 側に提供する。
- Next.js は BFF として Browser と Rails API の境界になる。
- Rails は業務ロジック、ドメインロジック、DBアクセスを担当する。
- Rails API は可能な限りインターネットから直接アクセスできない構成とする。
- Next.js から Rails への通信はサーバー間通信として扱う。
- Browser に Rails API の認証情報を渡さない。
- Browser に Rails API の内部 URL を公開しない。
- 認証・認可は Rails 側でも必ず実施する。
- Next.js の認証・CSRF対策だけを Rails の認証・認可の代替にしない。

### 2.3 サーバー間通信の多層防御

7.2 の JWT によるユーザー認証は、あくまで「誰のリクエストか」を Rails 側で識別するための仕組みであり、それ単体を Next.js ↔ Rails 間のネットワークレベルのアクセス制御の代わりにはしない。インフラ構成に応じて、以下のようなネットワークレベルの防御を併用する。

- Rails をプライベートサブネット等に配置し、インターネットから直接到達できないようにする
- Next.js ↔ Rails 間の通信を VPC 内限定など、許可されたネットワーク経路に制限する
- 必要に応じて mTLS 等、通信経路自体の相互認証を導入する

JWT 認証（アプリケーションレベル）とネットワーク的な到達性の制限（インフラレベル）は、どちらか一方で足りるものではなく、両方を組み合わせる。

---

# 3. レイヤーごとの責務

## 3.1 Browser / React

Browser / React の責務は UI とユーザー操作に限定する。

### 実施すること

- 画面表示
- ユーザー入力
- クライアント側バリデーション
- Next.js API の呼び出し
- APIレスポンスに応じた画面状態の変更

### 実施しないこと

- Rails API の直接呼び出し
- Rails API の URL を直接参照
- Rails API のアクセストークンを保持
- DBアクセス
- 業務ルールの最終判定

---

## 3.2 Next.js

Next.js は BFF として Browser 向け API を提供する。

### 実施すること

- Browser からのリクエスト受付
- 認証情報の確認
- CSRF対策
- Browser 向け入力値の基本チェック
- Rails API への Server-to-Server 通信
- Rails API のレスポンス変換
- 必要に応じた複数APIの集約
- Browser に不要な内部情報の除外
- エラーレスポンスの Browser 向け変換

### 実施しないこと

- 業務ルールの最終判定
- DBへの直接アクセス
- Rails と重複するドメインロジックの実装
- Rails API の認証・認可の代替

---

## 3.3 Rails API

Rails は Backend / Domain Server として業務処理を担当する。

### 実施すること

- 認証
- 認可
- 業務ルールの検証
- ドメインロジック
- トランザクション
- DBアクセス
- データ整合性の保証
- 業務エラーの判定
- 監査ログ等の記録

### 原則

業務上重要なチェックは必ず Rails 側で行う。

例えば、

```text
Next.js:
「入力された金額は数値か？」

Rails:
「このユーザーはこの支出を登録できるか？」
「この状態から承認してよいか？」
「この金額・勘定科目の組み合わせは業務ルール上正しいか？」
```

という責務分担とする。

---

# 4. APIアクセス規約

## 4.1 Browser から Rails API を直接呼び出さない

禁止:

```typescript
fetch("https://api.example.com/api/expenses");
```

Browser からは Next.js の API を呼び出す。

```typescript
fetch("/api/expenses");
```

---

## 4.2 Rails API の URL を Frontend にハードコードしない

禁止:

```typescript
const API_URL = "https://api.example.com";
```

または、

```typescript
fetch(`${process.env.NEXT_PUBLIC_RAILS_API_URL}/api/expenses`);
```

Browser で実行されるコードから Rails API URL を参照してはならない。

Rails API の URL は Next.js の Server 側でのみ管理する。

---

## 4.3 Server Component / Route Handler / Server Action

Rails API への通信は、原則として Next.js の Server 側から実行する。

利用可能な実装箇所:

- Route Handler
- Server Action
- Server Component
- Server-side utility

ただし、API の公開境界を明確にするため、外部からの API エンドポイントは原則 Route Handler に集約する。

例:

```text
app/
└── api/
    └── expenses/
        ├── route.ts
        └── [id]/
            └── route.ts
```

---

# 5. Next.js BFF API 規約

## 5.1 Browser 向け API

Next.js の API は Browser にとって使いやすいインターフェースとする。

例:

```http
POST /api/expenses
GET  /api/expenses
GET  /api/expenses/{id}
PATCH /api/expenses/{id}
```

Rails API の URL と完全に一致させる必要はない。

---

## 5.2 BFF でのレスポンス変換

Rails の内部情報をそのまま Browser に返さない。

例えば Rails が、

```json
{
  "id": 123,
  "internal_status": 10,
  "created_by_internal_id": 999
}
```

を返したとしても、Browser に不要な項目は除外する。

```json
{
  "id": 123,
  "status": "registered"
}
```

---

## 5.3 BFF で業務ロジックを実装しない

禁止:

```typescript
if (expense.amount > 100000) {
  // Next.jsで承認不可と判定
}
```

業務上の判定は Rails で行う。

Next.js は必要に応じて入力形式や UI 上の制約をチェックするが、最終判定は Rails に任せる。

---

# 6. CSRF 対策

## 6.1 CSRF 対策の対象

CSRF対策は主に、

```text
Browser → Next.js
```

の境界で考える。

Rails API が Browser から直接呼ばれない構成でも、Next.js が Cookie ベースの認証を利用する場合は CSRF 対策が必要である。

---

## 6.2 Cookie の利用

認証用 Cookie を利用する場合は、原則として以下を適切に設定する。

- HttpOnly
- Secure
- SameSite
- 適切な Path
- 必要最小限の Domain

例:

```text
HttpOnly = true
Secure   = true
SameSite = Lax または Strict
```

ただし、SameSite の値はシステム要件と認証方式を考慮して決定する。

---

## 6.3 CSRF 対策方式

状態変更 API（`POST` / `PUT` / `PATCH` / `DELETE`）は、以下を標準の CSRF 対策とする。GET などの参照系 API と状態変更 API は明確に区別する。

### 6.3.1 標準方式: SameSite Cookie + Origin検証

デフォルトでは CSRF Token を発行せず、次の2点の組み合わせで対策する。

1. **SameSite Cookie**（6.2）により、クロスサイトなフォーム送信・`fetch`/`XHR` からは認証 Cookie が送信されないようにする。
2. **Origin ヘッダー検証**を状態変更 API の Route Handler で行う。`Origin` ヘッダー（存在しない場合は `Referer` で代替）が自アプリの `Host` ヘッダーと一致しない場合はリクエストを拒否する（403）。

```typescript
function isSameOrigin(req: Request): boolean {
  const origin = req.headers.get("origin") ?? req.headers.get("referer");
  const host = req.headers.get("host");
  if (!origin || !host) return false;

  return new URL(origin).host === host;
}
```

比較対象は `req.url` ではなく `Host` ヘッダーとする。`req.url` はリバースプロキシやコンテナのポートフォワーディング構成下では、サーバーが内部的に待ち受けているポートに書き換わることがあり、Browser が実際にアクセスした外部向けのオリジンとは一致しなくなる場合があるため。

この検証は状態変更 API 共通のロジックとして実装し、各 Route Handler で重複させない（12章の `apiFetch` 等と同様に共通化する）。

### 6.3.2 CSRF Token を追加する場合

以下のようなケースでは、6.3.1 に加えて CSRF Token（Double Submit Cookie 方式）の導入を検討する。

- 古いブラウザ（SameSite Cookie 未対応）のサポートが要件に含まれる
- 認証 Cookie を複数サブドメイン間で共有する必要があり、SameSite だけでは保護範囲が不足する
- 外部サイトからの iframe 埋め込みなど、Origin 検証だけでは不十分な組み込み要件がある

上記に該当しない限り、CSRF Token の追加実装は行わない。

---

# 7. 認証・認可

## 7.1 Browser に Rails 用アクセストークンを持たせない

禁止:

```text
Browser
  ↓
Rails Access Token
```

Rails API 用の認証情報は Server-side に保持する。

---

## 7.2 Next.js → Rails

Next.js から Rails API にアクセスするときは、単なる「サーバー間の固定シークレット」ではなく、**どのユーザーのリクエストかを Rails 側で特定できるトークン**を転送する。

```http
Authorization: Bearer <user-scoped-jwt>
```

固定の共有シークレットのみをサーバー間認証として使うことは禁止する。Rails は 7.3 の通りリクエストごとに認可判定を行う必要があり、そのためには Rails 側でリクエストの主体（ユーザー）を一意に解決できなければならない。

### トークンの要件

- **形式**: 署名付き JWT とする。`sub`（ユーザーID）と有効期限（`exp`）を含む。
- **発行**: ログイン成功時に Rails がユーザーを認証したうえで発行する。Next.js は発行された JWT を Browser には渡さず、Server-side（httpOnly Cookie 等）にのみ保持する。
- **転送**: Next.js から Rails への各リクエストで、保持している JWT を `Authorization: Bearer` ヘッダーに設定する。
- **検証**: Rails は署名・有効期限を検証したうえでユーザーを解決し、そのユーザーに対して認可判定を行う。検証に失敗した場合は 401 を返す。
- **ローテーション**: 業務上必要な場合、Rails はレスポンスに新しい JWT（例: `next_token`）を含めて返し、Next.js は次回リクエスト用に Cookie を更新する。401 の場合は Cookie を更新・破棄し、再ログインを要求する。

固定トークンによるサービス間認証（AWS IAM 等、ユーザー非依存の内部サービス呼び出し）が別途必要な場合は、ユーザースコープの JWT とは別の仕組みとして明確に区別して設計する。

---

## 7.3 認可は Rails で必ず行う

Next.js が認証済みであっても、Rails はリクエストごとに認可を確認する。

```text
Browser
  ↓
Next.js
  ↓
Rails
     ├─ Authentication
     ├─ Authorization
     └─ Business validation
```

「Next.js で認証済みだから Rails では認可不要」としてはならない。

---

# 8. 入力バリデーション

## 8.1 Next.js

Next.js では UI / API 境界として基本的な入力チェックを行う。

例:

- 必須チェック
- 型チェック
- 文字数
- 形式
- 明らかな不正値

---

## 8.2 Rails

Rails では必ず業務上のバリデーションを行う。

例:

- 存在確認
- 権限確認
- 状態遷移
- 金額の妥当性
- 他データとの整合性
- 重複チェック
- 業務ルール

Next.js のバリデーションを Rails のバリデーションの代替として扱ってはならない。

---

# 9. エラーハンドリング

## 9.1 Rails

Rails API は HTTP Status を適切に返す。

例:

| Status | 用途 |
|---|---|
| 200 | 正常取得 |
| 201 | 正常作成 |
| 204 | 正常終了・レスポンスなし |
| 400 | リクエスト不正 |
| 401 | 未認証 |
| 403 | 権限なし |
| 404 | リソースなし |
| 409 | 業務上の競合 |
| 422 | 入力・業務バリデーションエラー |
| 500 | サーバーエラー |

---

## 9.2 Next.js

Next.js は Rails の内部エラーをそのまま Browser に返さない。

禁止:

```json
{
  "error": "PG::UniqueViolation: ..."
}
```

Browser 向けには安全なエラー形式に変換する。

例:

```json
{
  "code": "DUPLICATE_EXPENSE",
  "message": "同じ支出が既に登録されています。"
}
```

変換して捨てる元の情報（Rails のエラーメッセージ、スタックトレース、想定外のレスポンス本文など）は、Browser に返す前に相関ID（12.2章）付きで Next.js の Server-side ログに残す。Browser 向けに安全な形へ変換することと、調査に必要な情報を失うことはトレードオフではない。ログに残す内容は 10章 のルール（機密情報を出力しない）に従う。

Rails が JSON 以外（HTML のエラーページ等）を返した場合も同様に、その内容を Browser にそのまま転送しない。ログに残したうえで、Browser には安全な汎用エラーを返す。

---

# 10. ログ・機密情報

以下の情報をログに出力してはならない。

- パスワード
- アクセストークン
- Refresh Token
- Cookie の内容
- CSRF Token
- 個人情報
- API Secret
- AWS Secret
- その他の認証情報

Next.js の Server-side ログにも同じルールを適用する。

---

# 11. CORS

Browser → Rails API の直接アクセスを禁止する構成では、Rails API の CORS 設定を「すべて許可」にしない。

禁止:

```text
Access-Control-Allow-Origin: *
```

Rails API を外部 Browser から直接利用する必要がない場合、CORS は最小限または不要な構成とする。

ただし、将来的に別クライアントが Rails API を直接利用する場合は、その要件に応じて明示的な Origin を許可する。

---

# 12. APIクライアントの実装

Next.js から Rails API を呼び出す処理は共通化する。

例:

```text
src/
├── app/
│   └── api/
├── lib/
│   └── api/
│       ├── apiFetch.ts
│       └── errors.ts
└── ...
```

各 Route Handler から直接 `fetch()` の詳細処理を繰り返さない。

例:

```typescript
const response = await apiFetch("/expenses", {
  method: "POST",
  body: JSON.stringify(request),
});
```

`apiFetch` では以下を共通管理する。

- Rails API の Base URL
- 認証情報
- 共通 Header
- Content-Type
- Timeout
- エラー変換
- ログ
- リトライ方針

## 12.1 リトライ方針とべき等性

`apiFetch` の自動リトライは、**べき等なメソッド（`GET` / `HEAD`）に限定する**。`POST` / `PATCH` / `DELETE` のような非べき等な操作は自動リトライしない。

```text
GET, HEAD    → タイムアウト・ネットワークエラー時に apiFetch が自動リトライしてよい
POST, PATCH,
DELETE       → apiFetch は自動リトライせず、エラーをそのまま呼び出し元に返す
```

理由は、非べき等な操作をタイムアウト等で自動リトライすると、Rails 側で処理が実際には成功していた場合に二重登録・二重更新が発生しうるためである。この場合、リクエストが失敗したのか、処理は成功したがレスポンスだけ届かなかったのかを Next.js 側では区別できない。

非べき等な操作をリトライしたい場合は、`apiFetch` の暗黙のリトライではなく、以下のいずれかを個別に設計する。

- Browser 側でエラーを表示し、ユーザーの明示的な再操作に委ねる
- 業務上どうしても自動リトライが必要な場合は、Idempotency-Key 等による重複排除の仕組みを Rails 側に用意したうえで導入する（本規約の標準では未採用）

## 12.2 相関ID（トレースID）の伝搬

Next.js → Rails の呼び出しでは、`X-Request-Id` ヘッダーで相関IDを伝搬する。

- Next.js は Browser からのリクエストを受け付けた時点で相関ID（例: `crypto.randomUUID()`）を発行する。
- `apiFetch` は、その処理から呼び出す Rails API へのリクエストに、発行した相関IDを `X-Request-Id` ヘッダーとして付与する。
- Rails 側は標準の `ActionDispatch::RequestId` ミドルウェアがこのヘッダーをそのまま採用し `request.request_id` として扱うため、追加実装は不要である。`config.log_tags = [:request_id]` によりログに出力される。
- Next.js 側のサーバーログにも同じ相関IDを出力し、Next.js 側と Rails 側のログを同一のIDで突き合わせられるようにする。

例:

```http
X-Request-Id: 3fa85f64-5717-4562-b3fc-2c963f66afa6
```

障害調査時は、この相関IDをキーに Next.js 側・Rails 側双方のログを検索する。

---

# 13. 環境変数

Rails API の URL は Browser に公開される環境変数に設定しない。

禁止:

```text
NEXT_PUBLIC_RAILS_API_URL
```

Rails API の URL は Server-side 専用の環境変数として管理する。

例:

```text
RAILS_API_URL
```

秘密情報は環境変数や AWS Secrets Manager 等で管理し、Git にコミットしない。

---

# 14. トランザクション

業務上のトランザクションは Rails で管理する。

Next.js で複数の Rails API を呼び出して疑似的にトランザクションを実装しない。

禁止:

```text
Next.js
  ├─ POST /api/a
  ├─ POST /api/b
  └─ POST /api/c
```

を一連のDBトランザクションとして扱う。

複数データを一貫して更新する必要がある場合は、Rails にユースケース/APIを設計し、Rails のトランザクション内で処理する。

---

# 15. セキュリティ境界

セキュリティ境界は以下とする。

```text
┌──────────────────────────────┐
│ Browser                      │
│                              │
│ 信頼しないクライアント        │
└──────────────┬───────────────┘
               │
               │ HTTPS
               │ CSRF protection
               ▼
┌──────────────────────────────┐
│ Next.js                      │
│                              │
│ BFF / Browser API            │
└──────────────┬───────────────┘
               │
               │ Server-to-Server
               │ Authentication
               ▼
┌──────────────────────────────┐
│ Rails API                    │
│                              │
│ Authentication               │
│ Authorization                │
│ Business Logic               │
│ Transaction                  │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ PostgreSQL / Aurora           │
└──────────────────────────────┘
```

Browser は信頼できないクライアントとして扱う。

---

# 16. 禁止事項

以下を禁止する。

- Browser から Rails API を直接呼び出す
- Browser に Rails API の認証情報を保持させる
- Browser に Rails API の内部 URL を公開する
- Next.js だけで認証・認可を完結させる
- Next.js だけで業務ルールを判定する
- Rails のエラーメッセージをそのまま Browser に返す
- Token / Password / Cookie / CSRF Token をログ出力する
- `NEXT_PUBLIC_*` に Rails API の機密情報を設定する
- Rails API の CORS を無条件で `*` にする
- Next.js で DB に直接アクセスする
- Next.js で複数 API を組み合わせてDBトランザクションを擬似的に実現する

---

# 17. 推奨ディレクトリ構成

## Next.js

```text
nextjs-app/
├── src/
│   ├── app/
│   │   └── api/
│   │       ├── auth/
│   │       ├── expenses/
│   │       └── ...
│   ├── components/
│   ├── lib/
│   │   ├── api/
│   │   │   ├── apiFetch.ts
│   │   │   └── errors.ts
│   │   ├── auth/
│   │   └── csrf/
│   └── ...
└── ...
```

## Rails

```text
api/
├── app/
│   ├── controllers/
│   ├── services/
│   ├── models/
│   └── ...
├── config/
├── db/
├── docs/
│   └── interfaces/
│       └── rest/
└── spec/
```

Rails 側の OpenAPI / API仕様書は、既存の API ドキュメント構成に合わせて管理する。

---

# 18. API仕様書

API仕様書には少なくとも以下を記載する。

- API ID
- Method
- Path
- 概要
- 認証
- CSRF要否
- Request Header
- Request Body
- Response
- HTTP Status
- エラーコード
- 認可条件
- 業務ルール
- 例

Next.js BFF API と Rails API の仕様が異なる場合は、それぞれを明確に分離する。

```text
docs/
├── interfaces/
│   ├── frontend-api/
│   └── rails-api/
```

---

# 19. テスト方針

## 19.1 Next.js

以下をテストする。

- API Route の正常系
- 入力エラー
- 認証エラー
- CSRFエラー
- Rails API エラーの変換
- Rails API が利用できない場合
- Browser 向けレスポンス

## 19.2 Rails

以下をテストする。

- 認証
- 認可
- バリデーション
- 業務ルール
- トランザクション
- DB整合性
- 正常系
- 異常系
- 競合
- HTTP Status

Rails の業務ロジックを Next.js のテストだけで保証しない。

---

# 20. 開発時の実装順序

新しい機能を追加するときは、原則として以下の順番で実装する。

```text
1. ユースケース / 業務ルールを定義
        ↓
2. Rails API を設計
        ↓
3. Rails の認証・認可・業務処理を実装
        ↓
4. Rails API のテストを実装
        ↓
5. Next.js BFF API を実装
        ↓
6. Next.js API のテストを実装
        ↓
7. React UI を実装
        ↓
8. E2Eテスト
```

業務ロジックを先に Rails に確立し、その上に Next.js BFF と UI を構築する。

---

# 21. Rails API変更時の後方互換性とデプロイ順序

Next.js と Rails は個別にデプロイされる。既存 API を変更するときは、両者のデプロイタイミングにズレがあっても動作し続けるようにする。

## 21.1 Expand/Contract（拡張・収縮）方式

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

## 21.2 デプロイ順序

Expand/Contract の各フェーズで、デプロイ順序は次の通りとする。

```text
Expand:   Rails を先にデプロイ → 動作確認後、Next.js をデプロイ
Contract: Next.js を先にデプロイ（新仕様への移行完了）→ 動作確認後、Rails の旧実装を削除してデプロイ
```

Next.js と Rails を同時にデプロイしない。どちらか一方が先にリリースされた状態でも、他方が壊れないことをデプロイ前に確認する。

## 21.3 レビュー時の確認事項

既存 API を変更するプルリクエストでは、以下を確認する。

- [ ] 既存フィールドの削除・型変更・必須化など、破壊的変更を一度に行っていない
- [ ] Expand フェーズでは、旧フィールド・旧挙動が残ったままになっている
- [ ] Contract フェーズは、Next.js 側の移行が完了したことを確認してから行っている
- [ ] 変更内容に対してデプロイ順序（Expand: Rails→Next.js／Contract: Next.js→Rails）が正しい

---

# 22. 設計レビュー時のチェックポイント

新しい API を追加する際は、以下を確認する。

- [ ] Browser から Rails API を直接呼び出していない
- [ ] Browser → Next.js の状態変更 API で、Cookie の SameSite 設定と Origin/Referer 検証による CSRF 対策を実施している
- [ ] Browser に Rails API の認証情報を渡していない
- [ ] Rails で認証を行っている
- [ ] Rails で認可を行っている
- [ ] Next.js → Rails の通信で、固定シークレットのみに頼らずユーザーを一意に識別できるトークン（JWT 等）を転送している
- [ ] 業務ルールを Rails に実装している
- [ ] Rails API の URL を Browser に公開していない
- [ ] Rails API の URL は Server-side 環境変数で管理している
- [ ] 機密情報をログに出していない
- [ ] Next.js → Rails の通信で相関ID（X-Request-Id）を伝搬し、双方のログを突き合わせられる
- [ ] Rails の内部エラーを Browser にそのまま返していない
- [ ] DBアクセスは Rails のみが行っている
- [ ] トランザクションは Rails で管理している
- [ ] 非べき等な操作（POST/PATCH/DELETE）を apiFetch が自動リトライしていない
- [ ] CORS が必要最小限になっている
- [ ] Next.js API のテストがある
- [ ] Rails API のテストがある
- [ ] 既存 API の変更は Expand/Contract 方式に沿っており、デプロイ順序が正しい
- [ ] 一覧を返す API は、件数が増加しない前提でない限りページネーションを実装している

---

# 23. ファイルアップロード・大容量ペイロード

現時点でファイルアップロードを伴う API は存在しないが、将来追加する場合は以下を標準とする。

## 23.1 アップロード方式

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

- Browser から直接ストレージ（S3 等）にアップロードする Direct Upload 方式（署名付き URL を Browser に渡す方式）は採用しない。Browser に外部ストレージの URL を扱わせることになり、2章の「Browser に Rails API の内部 URL を公開しない」「Browser が利用する API は原則として Next.js 側に提供する」という原則と相容れないため。
- Next.js は受け取ったファイルを Rails にそのまま転送する。画像変換等の重い処理は Rails 側（Active Storage / image processing）で行い、Next.js では行わない（3章の責務分担に従う）。

## 23.2 サイズ制限

- Next.js Route Handler・Rails 双方で許容する最大リクエストサイズを明示的に設定し、無制限を許容しない。
- 実際の上限値はアップロード対象（画像、PDF 等）に応じて、機能追加時に決定する。

---

# 24. ページネーション・レート制限・リクエストサイズ制限

## 24.1 ページネーション

一覧を返す API（GET）は、件数が想定内で増加しないことが明らかな場合を除き、ページネーションを行う。

- 方式は limit/offset・cursor のいずれかを採用してよいが、同一 API 内で混在させない。
- `limit` のデフォルト値・最大値を明記し、上限を超える件数を一度に返さない。
- Next.js BFF は Rails API のページネーションパラメータを Browser 向けにそのまま透過してよいが、上限値の強制は Next.js 側でも行う。Browser から不正に大きな `limit` が指定された場合は上限値に丸める。

## 24.2 レート制限

レート制限は WAF / CloudFront 等のインフラ層で行うことを標準とする（2章参照）。Next.js・Rails のアプリケーションコードにレート制限の仕組みを個別実装しない。

インフラ層のレート制限だけでは表現できない業務固有の制限（例: ログイン試行回数の制限）が必要になった場合は、その時点で個別に設計する。

## 24.3 リクエスト/レスポンスサイズ制限

- Rails・Next.js とも、リクエストボディサイズの上限を明示的に設定し、無制限を許容しない。
- 一覧 API のレスポンスは 24.1 のページネーションにより件数を制限し、無制限に肥大化するレスポンスを返さない。

---

# 25. 基本方針まとめ

本システムでは、以下を標準アーキテクチャとする。

```text
Browser
   │
   │ HTTPS
   │ Cookie / CSRF protection
   ▼
Next.js BFF
   │
   │ Server-to-Server
   │ Authentication
   ▼
Rails API
   │
   │ Authorization
   │ Business Logic
   │ Transaction
   ▼
PostgreSQL / Aurora
```

重要なのは、**Next.js を単なる API プロキシとしてではなく、Browser と Rails のセキュリティ境界となる BFF として扱うこと**である。

一方で、Next.js に業務ロジックを移しすぎない。

- Next.js = Browser 向け API / BFF / UI
- Rails = 認証 / 認可 / 業務ロジック / DB
- PostgreSQL = データ永続化

という責務分担を維持する。

この責務分担を守ることで、セキュリティ・保守性・テスト容易性・将来的な拡張性を両立する。
