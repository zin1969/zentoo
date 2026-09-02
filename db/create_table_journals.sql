CREATE TABLE journals (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  journal_dt DATE NOT NULL,
  store_id INTEGER REFERENCES stores(id),
  store_name TEXT,
  user_id INTEGER REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trigger_update_updated_at_of_journals
BEFORE UPDATE ON journals
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_with_current_timestamp();
