CREATE OR REPLACE FUNCTION get_recurring_dates(
  interval_unit INT,
  interval_count INT,
  day_of_month INT,
  weekday INT,
  start_date DATE,
  end_date DATE,
  from_date DATE,
  to_date DATE
)
RETURNS SETOF DATE
LANGUAGE plpgsql AS $$
DECLARE
  v_from DATE;
  v_to DATE;
  v_start_month INT;
  v_first_step INT;
  v_last_step INT;
  INTERVAL_UNIT_MONTH CONSTANT INT := 1;
BEGIN
  -- 週単位（interval_unit = 2）は、このあとのタスクで足す
  IF interval_unit <> INTERVAL_UNIT_MONTH THEN
    RAISE EXCEPTION 'interval_unit not supported yet: %', interval_unit;
  END IF;

  -- 開始日より前・終了日より後の回は出さない
  v_from := GREATEST(from_date, start_date);
  v_to := LEAST(to_date, COALESCE(end_date, to_date));

  IF v_from > v_to THEN
    RETURN;
  END IF;

  -- 予定のある月は、開始日の月から interval_count ヶ月ごと。月を「年 × 12 + 月」の通し番号で数え、
  -- 期間にかかる回（step）だけを作る。月に無い日（2 月 30 日など）は月末にするので、31 日は月末になる
  v_start_month := EXTRACT(YEAR FROM start_date)::INT * 12 + EXTRACT(MONTH FROM start_date)::INT - 1;
  v_first_step := GREATEST(
    0,
    (EXTRACT(YEAR FROM v_from)::INT * 12 + EXTRACT(MONTH FROM v_from)::INT - 1 - v_start_month) / interval_count
  );
  v_last_step :=
    (EXTRACT(YEAR FROM v_to)::INT * 12 + EXTRACT(MONTH FROM v_to)::INT - 1 - v_start_month) / interval_count;

  RETURN QUERY
  SELECT d.d_date
    FROM GENERATE_SERIES(v_first_step, v_last_step) AS s(step)
   CROSS JOIN LATERAL (
     SELECT (v_start_month + s.step * interval_count) / 12 AS m_year,
            (v_start_month + s.step * interval_count) % 12 + 1 AS m_month
   ) m
   CROSS JOIN LATERAL (
     SELECT LEAST(
              MAKE_DATE(m.m_year, m.m_month, 1) + (day_of_month - 1),
              get_last_date_of_month(m.m_year, m.m_month)
            ) AS d_date
   ) d
   WHERE d.d_date BETWEEN v_from AND v_to
   ORDER BY d.d_date;
END;
$$;
