CREATE OR REPLACE FUNCTION get_tag_items(
  user_id INT,
  tag_id INT,
  from_date DATE,
  to_date DATE
)
RETURNS TABLE (
  journal_id BIGINT,
  journal_date DATE,
  store_name TEXT,
  item_name TEXT,
  account_id BIGINT,
  account_name TEXT,
  amount BIGINT
)
LANGUAGE plpgsql AS $$
DECLARE
  ELEMENT_EXPENSES CONSTANT INT := 5;
BEGIN
  -- タグは本人のものだけ。他ユーザーのタグと存在しないタグは区別しない
  IF NOT EXISTS (
    SELECT 1
      FROM tags tg
     WHERE tg.id = get_tag_items.tag_id
       AND tg.user_id = get_tag_items.user_id
  ) THEN
    RAISE EXCEPTION 'tag not found: %', tag_id;
  END IF;

  -- 期間内に、タグが付いた費用の明細を、仕訳日・明細の順に返す
  RETURN QUERY
  SELECT j.id::BIGINT, j.journal_dt, j.store_name, d.item_name, d.account_id::BIGINT, ea.name, d.amount::BIGINT
    FROM debit_tags dt
    JOIN debits d ON d.id = dt.debit_id
    JOIN journals j ON j.id = d.journal_id
    LEFT JOIN expense_accounts ea ON ea.id = d.account_id
   WHERE dt.tag_id = get_tag_items.tag_id
     AND d.element_type = ELEMENT_EXPENSES
     AND j.user_id = get_tag_items.user_id
     AND j.journal_dt BETWEEN from_date AND to_date
   ORDER BY j.journal_dt, d.id;
END;
$$;
