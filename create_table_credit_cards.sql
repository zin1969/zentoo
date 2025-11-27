CREATE TABLE credit_cards (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  liability_account_id INTEGER REFERENCES liability_accounts(id),
  bank_account_id INTEGER REFERENCES asset_accounts(id),
  cutoff_day INTEGER NOT NULL,
  payment_day INTEGER NOT NULL,
  user_id INTEGER REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  CHECK (cutoff_day BETWEEN 1 AND 31),
  CHECK (payment_day BETWEEN 1 AND 31)
);

CREATE TRIGGER trigger_update_updated_at_of_credit_cards
BEFORE UPDATE ON credit_cards
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_with_current_timestamp();
