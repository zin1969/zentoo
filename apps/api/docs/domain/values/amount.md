# Value Object 仕様書  
## Amount

## 1. 概要

### 名称
Amount

### 概要説明
Amount は金額を表す Value Object である。
金額に関する業務ルール（不正値防止・計算・比較）をプリミティブ型から切り離し、ドメイン層に集約することを目的とする。

注文金額、請求金額、仕訳金額など、**金銭的価値を扱うすべての文脈で使用される基本概念**である。


---

## 2. Value Object 採用理由

## なぜプリミティブではダメか
- [x] 値に業務上の意味がある
- [x] 計算・制約ルールが存在する
- [x] 誤った値(負数・不正型)が入ると業務ロジックが破壊される

Amount は数値だが、単なる Integer / Decimal では「負数禁止」「計算単位」「比較ルール」などを保証できない。

### enum を使わない理由（該当する場合）
該当なし（区分値ではない）

---

## 3. 定義

### 内部値
- 型：BigDecimal
- NULL 許容：不可

### 許可される値
- 0 以上の整数

---

## 4. 業務ルール・制約
- 金額は必ず 0 以上でなければならない
- 負の値は生成時に例外とする
- 単位（円など）は別概念で扱い、本 VO では扱わない

---

## 5. 振る舞い（メソッド）

### 判定系（predicate）
- `zero?`：金額が 0 かどうか
- `positive?`：正の値かどうか

### 変換系
- `to_d` : BigDecimal へ変換
- `to_i` : Integer へ変換（表示・外部連携用）

### 計算系
- `add(other)`：加算
- `subtract(other)`：減算

計算結果も Amount として返す

---

## 6. 同値性

### 同値判定基準
- 内部の value が等しい場合、同一とみなす

### 実装方針
- `==` / `eql?`
- `hash` は value.hash を使用する

---

## 7. ActiveRecord::Type

- Type クラス名：AmountType
- cast:
  - nil を許容
  - 既に Amount の場合はそのまま返却
- serialize:
  - Amount -> Integer

---
## 7. 実装ファイル

```text
app/values/
 └ amount.rb

app/types/
 └ amount_type.rb
```
