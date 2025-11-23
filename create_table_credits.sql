CREATE TABLE credits (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  journal_id INTEGER REFERENCES journals(id),
  type INTEGER NOT NULL,
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
  CONSTRAINT credit_type CHECK (type IN (1, 2, 3, 4, 5)),
  CONSTRAINT credit_payment_method_type CHECK (
    (type = 1 AND payment_method_type IN (1, 2, 3)) OR
    (type = 2 AND payment_method_type IN (1, 2, 3))
  )
);

CREATE TRIGGER trigger_update_updated_at_of_credits
BEFORE UPDATE ON credits
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_with_current_timestamp();
