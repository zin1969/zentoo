# Value Object 完成規約  
（Rails × DDD 実務向け 最終版）

---

## 1. 目的
本規約は、Rails アプリケーションにおいて  
DDD（ドメイン駆動設計）に基づく Value Object（以下 VO）を一貫したルールで設計・実装することを目的とする。

---

## 2. Value Object の定義
- VO は値そのものを表すドメインオブジェクト
- ID を持たない
- 同値性は内部の値で決まる
- 状態は不変（Immutable）

---

## 3. 基本原則
### 3.1 不変性
- 生成後に状態変更を行わない
- setter を持たない
- 状態変更は新しいインスタンスを生成する

```ruby
# OK
new_amount = amount.add(100)

# NG
amount.value = 100
```

### 3.2 プリミティブ型のラップ
- String / Integer / BigDecimal 等を直接扱わない
- 業務上意味を持つ値は必ず VO とする

---

## 4. ディレクトリ規約
```text
app/
 ├ values/          # ドメイン層
 │   ├ amount.rb
 │   ├ email.rb
 │   └ period.rb
 │
 ├ types/           # インフラ層（Rails）
 │   ├ amount_type.rb
 │   └ email_type.rb
```

**役割**
| ディレクトリ     | 役割             | Rails依存 |
| ---------- | -------------- | ------- |
| app/values | 業務ルール・振る舞い・同値性 | なし      |
| app/types  | DB ↔ VO 変換     | あり      |

---

## 5. 命名規約

**Value Object**
- 名詞・単数形
- 業務用語（ユビキタス言語）を使用
- *Value, *VO などの接尾辞は禁止

```ruby
Amount
Email
AccountingPeriod
```

**ActiveRecord::Type**
- {ValueObject}Type
- 原則 1 VO に 1 Type

```ruby
AmountType
EmailType
```

---

## 6. Value Object 実装規約

### 6.1 初期化時の完全性保証
- initialize で完全性を保証
- initialize で妥当性を検証する
- 不正な値は生成できない

```ruby
class Amount
  def initialize(value)
    @value = BigDecimal(value.to_s)
    raise ArgumentError, 'must be >= 0' if @value.negative?
  end
end
```

### 6.2 nil の扱い
- nil は VO で扱わない
- nil 許容は Type 側で行う

### 6.3 同値性の定義
- ==, eql?, hash を実装
- 内部の値が同じなら同一とみなす

```ruby
def ==(other)
  other.is_a?(self.class) && value == other.value
end

alias eql? ==

def hash
  value.hash
end
```

### 6.4 振る舞いの実装
- 値に関する業務ロジックは VO に集約する
- 単なる getter にしない

```ruby
def add(other)
  self.class.new(value + other.value)
end
```

---

## 7. ActiveRecord::Type 規約

### 7.1 使用方針
- DB 保存される VO は必ず Type を持つ
- 永続化されない VO は Type を作らない

### 7.2 Type の責務
- DB → VO 変換（cast）
- VO → DB 変換（serialize）
- nil の吸収
- 二重ラップ防止

### 7.3 Type 実装テンプレ（確定）

```ruby
# app/types/amount_type.rb
class AmountType < ActiveRecord::Type::Decimal
  def cast(value)
    return if value.nil?
    return value if value.is_a?(Amount)

    Amount.new(value)
  end

  def serialize(value)
    return if value.nil?
    return value.value if value.is_a?(Amount)

    value
  end
end
```

### 7.4 Model での使用方法

```ruby
class Order < ApplicationRecord
  attribute :amount, AmountType.new
end
```

---

## 8. 依存方向ルール（厳守）
```pgsql
Application / Domain
        ↓
ActiveRecord::Type
        ↓
Value Object
```

- VO は Rails / DB を知らない
- Type は VO を知ってよい

---

## 9. 禁止事項🚫
- ActiveRecord を継承する
- VO 内で Rails / DB に依存する
- setter を定義する
- nil を VO に渡す
- VO を単なる構造体として使う

---

## 10. テスト
spec/values 配下に配置

```text
spec/
 └ values/
    └ amount_spec.rb
```

**必須テスト観点**
- 正常生成
- 不正値での例外
- 同値性
- 振る舞い

---

## 11. 推奨運用ルール
- Controller / Form / API  
→ プリミティブ
- Domain / Entity / FormObject
→ Value Object
- Entity 内では 常に VO を扱う

---

## 12. 判断基準（迷ったら）
| 状況       | 判断        |
| -------- | --------- |
| 業務ルールがある | VO        |
| DB に保存する | VO + Type |
| 一時的計算値   | VO のみ     |
| 表示専用     | プリミティブ    |

---

## 13. まとめ（最終結論）
- Value Object は 業務の言葉をコードにする
- Rails とは ActiveRecord::Type でつなぐ
- app/values と app/types を分離することで DDD と Rails の両立が可能になる
