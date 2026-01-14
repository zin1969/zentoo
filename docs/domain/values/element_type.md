# ElementType

## 概要
ElementType は会計上の「要素区分」を表す Value Object である。

## 定義
| value | 英語名 | 日本語名 |
|------|------|--------|
| 1 | assets | 資産 |
| 2 | liabilities | 負債 |
| 3 | equity | 純資産 |
| 4 | revenue | 収益 |
| 5 | expenses | 費用 |

## 設計方針
- enum は使用しない
- Value Object として不変性を保証する
- DB CHECK 制約と整合する

## 業務ルール
- 要素区分の追加・変更は禁止
- 会計基準変更時のみ見直す

## 実装
- app/values/element_type.rb
- app/types/element_type_type.rb
