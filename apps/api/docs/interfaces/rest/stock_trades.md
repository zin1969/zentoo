# 株の売買 API

現物株の買い・売りの仕訳を登録する REST API（M18）。
銘柄ごとに種別「投資」の資産の口座を 1 つ作り（例: 「トヨタ 7203」）、取得額はその口座の残高、株数は明細の株数（`shares`）の合計で管理する。
相手の口座は証券口座（預り金。種別「証券口座」）。

---

## Endpoint

```text
POST /stock-trades
```

## Authentication / Authorization
- Authorization ヘッダに Bearer トークンを指定する
- 持ち主は認証済みユーザー。本文に `user_id` を送っても無視する
- 銘柄・証券口座は本人の口座だけ使える。それ以外は存在しないものと同じ 404 を返す
- 401 以外では、本文に新しい `next_token` を返す

## Request

### Headers
| Name          | Required | Description      |
| ------------- | -------- | ---------------- |
| Authorization | Yes      | Bearer {token}   |
| Content-Type  | Yes      | application/json |

### Body

```json
{
  "trade_type": "sell",
  "journal_date": "2026-11-20",
  "stock_account_id": 21,
  "securities_account_id": 20,
  "shares": 50,
  "amount": 140000
}
```

| Name                  | Required | Description |
| --------------------- | -------- | ----------- |
| trade_type            | Yes      | `buy`（買い）か `sell`（売り） |
| journal_date          | Yes      | 約定日（`YYYY-MM-DD`） |
| stock_account_id      | Yes      | 銘柄（種別「投資」の口座）の ID |
| securities_account_id | Yes      | 証券口座（種別「証券口座」の口座）の ID |
| shares                | Yes      | 株数（1 〜 2147483647） |
| amount                | Yes      | 受渡金額（1 〜 2147483647）。買いは証券口座から出ていった額（手数料込み）、売りは証券口座に入った額（手数料・税金を引いたあと） |

## 仕訳の作り方

| 売買 | 借方 | 貸方 |
| ---- | ---- | ---- |
| 買い | 銘柄（株数 +n、受渡金額） | 証券口座（受渡金額） |
| 売り（高く売った） | 証券口座（受渡金額） | 銘柄（株数 −n、取得額）、株式売却益（受渡金額 − 取得額） |
| 売り（安く売った） | 証券口座（受渡金額）、株式売却損（取得額 − 受渡金額） | 銘柄（株数 −n、取得額） |
| 売り（同じ額） | 証券口座（受渡金額） | 銘柄（株数 −n、取得額） |

- 買いは DB 関数 `create_stock_buy_journal`、売りは `create_stock_sell_journal`。摘要は「買い 銘柄名」「売り 銘柄名」
- 手数料は取得額に含める（買いの受渡金額に入っている）。売りの手数料・税金は、受渡金額から引かれているので損益に入る
- 売りで減らす取得額は移動平均: 約定日（含む）までの 取得額 ÷ 株数 × 売る株数（四捨五入）。全部売るときは、端数を残さないよう取得額をそのまま減らす
- 売却益は収益科目「株式売却益」、売却損は費用科目「株式売却損」。どちらも共通科目を名前で探す（マイグレーション `20261128130000` で入れている）。管理画面で名前を変えたり削除したりすると、売りが 422 になる
- 約定日に持っている株数より多くは売れない
- その銘柄に約定日より後の日付の売りがあると、買い・売りとも登録できない（その売りの取得額が合わなくなるため）。後の売りを [仕訳削除 API](delete_journal.md) で削除してから、日付の順に登録し直す。売りより前の買い・開始残高を削除したときも、後の売りを削除して登録し直す（自動では計算し直さない）
- 修正はできない。削除して登録し直す。買いの仕訳は振替と同じ形（借方・貸方が口座 1 つずつ）だが、株数を持つので [振替の修正](transfer_journals.md) では直せない
- 配当は [収入 API](income_journals.md) で、入金先を証券口座、収益科目を「配当金」にして、源泉徴収のあとの手取りの額で登録する（銘柄の株数・取得額は変わらない）
- 今持っている株は [開始資産 API](asset_opening_journals.md) に `shares` を付けて登録する
- 銘柄ごとの株数・取得額は [保有株 API](stock_holdings.md) で見る

## Response

### Success (201 Created)

```json
{
  "journal_id": 51,
  "next_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

### Errors
| Status | error / errors | 内容 |
| ------ | -------------- | ---- |
| 404 | `stock_account_not_found` | 銘柄が存在しない、他ユーザーの口座、または種別「投資」ではない |
| 404 | `securities_account_not_found` | 証券口座が存在しない、他ユーザーの口座、または種別「証券口座」ではない |
| 422 | `insufficient_shares` | 約定日に持っている株数より多く売ろうとした |
| 422 | `later_sale_exists` | その銘柄に、約定日より後の日付の売りがある |
| 422 | `stock_gain_account_not_found` | 収益科目「株式売却益」が見つからない（高く売ったとき） |
| 422 | `stock_loss_account_not_found` | 費用科目「株式売却損」が見つからない（安く売ったとき） |
| 422 | `errors` | 本文のバリデーションエラー |

```json
{
  "error": "insufficient_shares",
  "next_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

### Authorization Error (401 Unauthorized)

```json
{
  "error": "unauthorized"
}
```
