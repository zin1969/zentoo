CREATE TABLE liability_accounts (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  type INTEGER NOT NULL,
  name TEXT NOT NULL,
  user_id INTEGER REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  -- 1: 借入金(住宅ローン、教育ローン等)
  -- 2: キャッシング
  -- 3: クレジットカード払い
  CONSTRAINT liability_account_type CHECK (type IN (1, 2, 3))
);

CREATE TRIGGER trigger_update_updated_at_of_liability_accounts
BEFORE UPDATE ON liability_accounts
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_with_current_timestamp();
