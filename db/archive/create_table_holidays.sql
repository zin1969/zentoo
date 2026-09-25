CREATE TABLE holiday_types (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trigger_update_updated_at_of_holiday_types
BEFORE UPDATE ON holiday_types
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_with_current_timestamp();

CREATE TABLE holidays (
  holiday DATE PRIMARY KEY,
  holiday_type_id INTEGER REFERENCES holiday_types(id),
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trigger_update_updated_at_of_holidays
BEFORE UPDATE ON holidays
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_with_current_timestamp();
