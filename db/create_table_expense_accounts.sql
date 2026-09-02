CREATE TABLE expense_accounts (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  parent_id INTEGER REFERENCES expense_accounts(id),
  name TEXT NOT NULL,
  user_id INTEGER REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trigger_update_updated_at_of_expense_accounts
BEFORE UPDATE ON expense_accounts
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_with_current_timestamp();
