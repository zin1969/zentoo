CREATE OR REPLACE FUNCTION get_last_date_of_month(
  y INT,
  m INT
)
RETURNS DATE
LANGUAGE plpgsql AS $$
DECLARE
  v_first_date_of_next_month DATE;
BEGIN
  v_first_date_of_next_month := (MAKE_DATE(y, m, 1) + INTERVAL '1 month')::DATE;

  RETURN v_first_date_of_next_month - 1;
END;
$$;
