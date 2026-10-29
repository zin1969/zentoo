CREATE OR REPLACE FUNCTION get_payment_date(
  cutoff_day INT,
  payment_day INT,
  journal_date DATE
)
RETURNS DATE
LANGUAGE plpgsql AS $$
DECLARE
  v_first_date_of_month DATE;
  v_cutoff_date DATE;
  v_months_ahead INT;
  v_payment_month DATE;
  v_payment_date DATE;
BEGIN
  v_first_date_of_month := DATE_TRUNC('month', journal_date)::DATE;

  -- 30・31 日締めのように月に存在しない日は、その月の末日に丸める
  v_cutoff_date := LEAST(
    v_first_date_of_month + (cutoff_day - 1),
    get_last_date_of_month(
      EXTRACT(YEAR FROM journal_date)::INT,
      EXTRACT(MONTH FROM journal_date)::INT
    )
  );

  -- 締日が支払日より前なら当月払い・翌月払い、締日が支払日以降なら翌月払い・翌々月払い
  IF cutoff_day < payment_day THEN
    v_months_ahead := CASE WHEN journal_date <= v_cutoff_date THEN 0 ELSE 1 END;
  ELSE
    v_months_ahead := CASE WHEN journal_date <= v_cutoff_date THEN 1 ELSE 2 END;
  END IF;

  v_payment_month := (v_first_date_of_month + (v_months_ahead * INTERVAL '1 month'))::DATE;

  -- 支払日も月に存在しない日（2 月 30 日など）は末日に丸める
  v_payment_date := LEAST(
    v_payment_month + (payment_day - 1),
    get_last_date_of_month(
      EXTRACT(YEAR FROM v_payment_month)::INT,
      EXTRACT(MONTH FROM v_payment_month)::INT
    )
  );

  RETURN get_next_business_day(v_payment_date);
END;
$$;
