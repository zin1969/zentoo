# Value Object 仕様書  
## ElementType

## 1. 概要

### 名称
ElementType

### 概要説明
ElementType は会計上の「要素区分」を表す Value Object である。

---

## 2. Value Object 採用理由

## なぜプリミティブではダメか
ElementType は数値だが、 1 = 資産 / 2 = 負債 … という業務的意味を持つため単なる Integer では表現できない。

### enum を使わない理由（該当する場合）
- [ ] ドメイン知識を Model に閉じ込めたくない
- [ ] Rails 依存を避けたい
- [ ] 振る舞いを持たせたい

---

## 3. 定義

### 内部値
- 型：Integer
- NULL 許容：不可

### 許可される値（区分値の場合）

| value | 英語名 | 日本語名 | 備考 |
|------|------|--------|----|
| 1 | assets | 資産 |    |
| 2 | liabilities | 負債 |    |
| 3 | equity | 純資産 |    |
| 4 | revenue | 収益 |    |
| 5 | expenses | 費用 |    |

---

## 4. 業務ルール・制約
- 会計基準に基づく固定概念のため追加禁止
- 不正な値は生成時に例外とする
- 会計基準変更時のみ見直す

---

## 5. 振る舞い（メソッド）

### 判定系（predicate）
- assets?
- liabilities?
- equity?
- revenue?
- expenses?

### 変換系
- `to_i`
- `to_s`

### 業務ロジック
- name
- japanese_name

---

## 6. 同値性

### 同値判定基準
- 内部の value が等しい場合、同一とみなす

### 実装方針
- `==` / `eql?`
- `hash` は value.hash を使用する

---

## 7. ActiveRecord::Type

- Type クラス名：ElementTypeType
- cast:
  - nil を許容
  - 既に ElementType の場合はそのまま返却
- serialize:
  - ElementType -> Integer

---

## 8. 実装ファイル

```text
app/values/
 └ element_type.rb

app/types/
 └ element_type_type.rb
```
