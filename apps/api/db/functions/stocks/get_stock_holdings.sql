CREATE OR REPLACE FUNCTION get_stock_holdings(
  user_id INT,
  as_of_date DATE
)
RETURNS TABLE (
  account_id BIGINT,
  account_name TEXT,
  shares BIGINT,
  cost BIGINT
)
LANGUAGE plpgsql AS $$
DECLARE
  ELEMENT_ASSETS CONSTANT INT := 1;
  ASSET_TYPE_INVESTMENT CONSTANT INT := 5;
BEGIN
  -- 銘柄は種別「投資」の口座。指定日（含む）までの仕訳から、株数（借方 - 貸方）と取得額（口座の残高）を求める。
  -- iDeCo・NISA のように株数を持たない投資の口座は、株の銘柄ではないので出さない
  RETURN QUERY
  WITH movements AS (
    SELECT d.account_id AS account_id, d.shares::BIGINT AS shares, d.amount::BIGINT AS amount
      FROM debits d
      JOIN journals j ON j.id = d.journal_id
     WHERE j.user_id = get_stock_holdings.user_id
       AND j.journal_dt <= as_of_date
       AND d.element_type = ELEMENT_ASSETS
    UNION ALL
    SELECT c.account_id, -c.shares::BIGINT, -c.amount::BIGINT
      FROM credits c
      JOIN journals j ON j.id = c.journal_id
     WHERE j.user_id = get_stock_holdings.user_id
       AND j.journal_dt <= as_of_date
       AND c.element_type = ELEMENT_ASSETS
  )
  SELECT aa.id::BIGINT,
         aa.name,
         COALESCE(SUM(m.shares), 0)::BIGINT,
         COALESCE(SUM(m.amount), 0)::BIGINT
    FROM asset_accounts aa
    JOIN movements m ON m.account_id = aa.id
   WHERE aa.user_id = get_stock_holdings.user_id
     AND aa.asset_type = ASSET_TYPE_INVESTMENT
   GROUP BY aa.id, aa.name
  HAVING COUNT(m.shares) > 0
   ORDER BY aa.id;
END;
$$;
