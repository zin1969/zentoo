CREATE OR REPLACE FUNCTION get_tag_monthly_totals(
  user_id INT,
  tag_id INT,
  target_year INT
)
RETURNS TABLE (
  month INT,
  amount BIGINT
)
LANGUAGE plpgsql AS $$
DECLARE
  v_year_start DATE;
  ELEMENT_EXPENSES CONSTANT INT := 5;
BEGIN
  -- タグは本人のものだけ。他ユーザーのタグと存在しないタグは区別しない
  IF NOT EXISTS (
    SELECT 1
      FROM tags tg
     WHERE tg.id = get_tag_monthly_totals.tag_id
       AND tg.user_id = get_tag_monthly_totals.user_id
  ) THEN
    RAISE EXCEPTION 'tag not found: %', tag_id;
  END IF;

  v_year_start := MAKE_DATE(target_year, 1, 1);

  -- タグが付いた費用の明細を、仕訳日（買った日）の月ごとに合計する。明細の無い月も 0 で返す
  RETURN QUERY
  SELECT m.m_month::INT, COALESCE(SUM(t.t_amount), 0)::BIGINT
    FROM GENERATE_SERIES(1, 12) AS m(m_month)
    LEFT JOIN (
      SELECT EXTRACT(MONTH FROM j.journal_dt)::INT AS t_month, d.amount::BIGINT AS t_amount
        FROM debit_tags dt
        JOIN debits d ON d.id = dt.debit_id
        JOIN journals j ON j.id = d.journal_id
       WHERE dt.tag_id = get_tag_monthly_totals.tag_id
         AND d.element_type = ELEMENT_EXPENSES
         AND j.user_id = get_tag_monthly_totals.user_id
         AND j.journal_dt >= v_year_start
         AND j.journal_dt < (v_year_start + INTERVAL '1 year')::DATE
    ) t ON t.t_month = m.m_month
   GROUP BY m.m_month
   ORDER BY m.m_month;
END;
$$;
