CREATE TABLE direct_debit_journals (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  original_id INTEGER REFERENCES journals(id),
  direct_debit_id INTEGER REFERENCES journals(id),
  user_id INTEGER REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trigger_update_updated_at_of_direct_debit_journals
BEFORE UPDATE ON direct_debit_journals
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_with_current_timestamp();
