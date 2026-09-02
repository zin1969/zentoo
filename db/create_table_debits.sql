CREATE TABLE debits (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  journal_id INTEGER REFERENCES journals(id),
  element_type INTEGER NOT NULL,
  account_id INTEGER NOT NULL,
  item_name TEXT,
  amount INTEGER NOT NULL,
  user_id INTEGER REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  -- 1: 資産(assets)
  -- 2: 負債(liabilities)
  -- 3: 純資産・資本(equity)
  -- 4: 収益(revenue)
  -- 5: 費用(expenses)
  CONSTRAINT debit_element_type CHECK (element_type IN (1, 2, 3, 4, 5))
);

CREATE TRIGGER trigger_update_updated_at_of_debits
BEFORE UPDATE ON debits
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_with_current_timestamp();
