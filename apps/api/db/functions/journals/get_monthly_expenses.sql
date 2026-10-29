CREATE OR REPLACE FUNCTION get_monthly_expenses(
  user_id INT,
  target_month DATE
)
RETURNS TABLE (
  account_id BIGINT,
  account_name TEXT,
  amount BIGINT
)
LANGUAGE plpgsql AS $$
DECLARE
  v_month_start DATE;
  ELEMENT_EXPENSES CONSTANT INT := 5;
BEGIN
  -- target_month は月内のどの日付でもよい
  v_month_start := DATE_TRUNC('month', target_month)::DATE;

  -- 仕訳日が当月の費用科目の借方を、科目ごとに合計する（金額の大きい順）
  RETURN QUERY
  SELECT ea.id::BIGINT, ea.name, SUM(d.amount)::BIGINT
    FROM debits d
    JOIN journals j ON j.id = d.journal_id
    JOIN expense_accounts ea ON ea.id = d.account_id
   WHERE d.element_type = ELEMENT_EXPENSES
     AND j.user_id = get_monthly_expenses.user_id
     AND j.journal_dt >= v_month_start
     AND j.journal_dt < (v_month_start + INTERVAL '1 month')::DATE
   GROUP BY ea.id, ea.name
   ORDER BY SUM(d.amount) DESC, ea.id;
END;
$$;
