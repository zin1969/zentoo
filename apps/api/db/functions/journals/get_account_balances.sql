CREATE OR REPLACE FUNCTION get_account_balances(
  user_id INT,
  as_of_date DATE
)
RETURNS TABLE (
  element_type INT,
  account_id BIGINT,
  account_name TEXT,
  balance BIGINT
)
LANGUAGE plpgsql AS $$
DECLARE
  ELEMENT_ASSETS CONSTANT INT := 1;
  ELEMENT_LIABILITIES CONSTANT INT := 2;
BEGIN
  -- 指定日（含む）までの仕訳から、資産・負債科目ごとの借方合計・貸方合計を求める
  -- 資産の残高は「借方 - 貸方」、負債の残高（未払いの額）は「貸方 - 借方」
  RETURN QUERY
  WITH movements AS (
    SELECT d.element_type, d.account_id, d.amount::BIGINT AS debit_amount, 0::BIGINT AS credit_amount
      FROM debits d
      JOIN journals j ON j.id = d.journal_id
     WHERE j.user_id = get_account_balances.user_id
       AND j.journal_dt <= as_of_date
       AND d.element_type IN (ELEMENT_ASSETS, ELEMENT_LIABILITIES)
    UNION ALL
    SELECT c.element_type, c.account_id, 0::BIGINT, c.amount::BIGINT
      FROM credits c
      JOIN journals j ON j.id = c.journal_id
     WHERE j.user_id = get_account_balances.user_id
       AND j.journal_dt <= as_of_date
       AND c.element_type IN (ELEMENT_ASSETS, ELEMENT_LIABILITIES)
  ), totals AS (
    SELECT m.element_type, m.account_id,
           SUM(m.debit_amount) AS debit_total,
           SUM(m.credit_amount) AS credit_total
      FROM movements m
     GROUP BY m.element_type, m.account_id
  )
  SELECT ELEMENT_ASSETS, aa.id::BIGINT, aa.name,
         (COALESCE(t.debit_total, 0) - COALESCE(t.credit_total, 0))::BIGINT
    FROM asset_accounts aa
    LEFT JOIN totals t ON t.element_type = ELEMENT_ASSETS AND t.account_id = aa.id
   WHERE aa.user_id = get_account_balances.user_id
  UNION ALL
  SELECT ELEMENT_LIABILITIES, la.id::BIGINT, la.name,
         (COALESCE(t.credit_total, 0) - COALESCE(t.debit_total, 0))::BIGINT
    FROM liability_accounts la
    LEFT JOIN totals t ON t.element_type = ELEMENT_LIABILITIES AND t.account_id = la.id
   WHERE la.user_id = get_account_balances.user_id
  ORDER BY 1, 2;
END;
$$;
