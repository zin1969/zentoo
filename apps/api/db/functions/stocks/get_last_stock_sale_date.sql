CREATE OR REPLACE FUNCTION get_last_stock_sale_date(
  stock_account_id INT
)
RETURNS DATE
LANGUAGE plpgsql
AS $$
DECLARE
  v_last_date DATE;
  ELEMENT_ASSETS CONSTANT INT := 1;
BEGIN
  -- 売りは、銘柄が貸方で株数を持つ明細。売りが無ければ NULL
  SELECT MAX(j.journal_dt)
    INTO v_last_date
    FROM credits c
    JOIN journals j ON j.id = c.journal_id
   WHERE c.element_type = ELEMENT_ASSETS
     AND c.account_id = get_last_stock_sale_date.stock_account_id
     AND c.shares IS NOT NULL
  ;

  RETURN v_last_date;
END;
$$;
