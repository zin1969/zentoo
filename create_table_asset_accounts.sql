CREATE TABLE asset_accounts (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  type INTEGER NOT NULL,
  name TEXT NOT NULL,
  user_id INTEGER REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  -- 1: 現金
  -- 2: 預貯金（銀行、信用金庫、郵貯等）
  -- 3: eManey
  CHECK (type IN (1, 2, 3))
);

CREATE TRIGGER trigger_update_updated_at_of_asset_accounts
BEFORE UPDATE ON asset_accounts
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_with_current_timestamp();
