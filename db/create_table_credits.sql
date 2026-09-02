CREATE TABLE credits (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  journal_id INTEGER REFERENCES journals(id),
  element_type INTEGER NOT NULL,
  payment_method_type INTEGER NOT NULL,
  account_id INTEGER NOT NULL,
  amount INTEGER NOT NULL,
  user_id INTEGER REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  -- 1: 資産(assets)
  -- 2: 負債(liabilities)
  -- 3: 純資産・資本(equity)
  -- 4: 収益(revenue)
  -- 5: 費用(expenses)
  CONSTRAINT credit_element_type CHECK (element_type IN (1, 2, 3, 4, 5)),
  -- 1: 資産(assets)
  --   1: 現金
  --   2: 預貯金（銀行、信用金庫、郵貯等）
  --   3: eManey
  -- 2: 負債(liabilities)
  --   1: 借入金(住宅ローン、教育ローン等)
  --   2: キャッシング
  --   3: クレジットカード払い
  -- 資産、負債以外
  --   0: 指定なし
  CONSTRAINT credit_payment_method_type CHECK (
    (element_type = 1 AND payment_method_type IN (1, 2, 3)) OR
    (element_type = 2 AND payment_method_type IN (1, 2, 3)) OR
    (element_type IN (3, 4, 5) AND payment_method_type = 0)
  )
);

CREATE TRIGGER trigger_update_updated_at_of_credits
BEFORE UPDATE ON credits
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_with_current_timestamp();
