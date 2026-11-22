CREATE OR REPLACE FUNCTION create_income_journal(
  journal_date DATE,
  asset_account_id INT,
  revenue_account_id INT,
  amount INT,
  description TEXT,
  user_id INT
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
  v_revenue_name TEXT;
  new_journal_id INT;
  ELEMENT_ASSETS CONSTANT INT := 1;
  ELEMENT_REVENUE CONSTANT INT := 4;
  NO_PAYMENT_METHOD CONSTANT INT := 0;
BEGIN
  IF amount <= 0 THEN
    RAISE EXCEPTION 'amount must be greater than 0';
  END IF;

  -- 入金先は本人の口座ならどれでもよい（預金・現金・電子マネー）。他人の口座と存在しない口座は区別しない
  IF NOT EXISTS (
    SELECT 1
      FROM asset_accounts aa
     WHERE aa.id = create_income_journal.asset_account_id
       AND aa.user_id = create_income_journal.user_id
  ) THEN
    RAISE EXCEPTION 'asset_account not found: %', asset_account_id;
  END IF;

  -- 収益科目は共通科目か本人の科目
  SELECT ra.name
    INTO v_revenue_name
    FROM revenue_accounts ra
   WHERE ra.id = create_income_journal.revenue_account_id
     AND (ra.user_id IS NULL OR ra.user_id = create_income_journal.user_id)
  ;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'revenue_account not found: %', revenue_account_id;
  END IF;

  -- 摘要（支払元など）は通帳の摘要に出るので、空なら収益科目の名前を入れる
  INSERT INTO journals (
    journal_dt, store_name, user_id
  ) VALUES (
    journal_date,
    COALESCE(NULLIF(BTRIM(description), ''), v_revenue_name),
    user_id
  )
  RETURNING id INTO new_journal_id;

  -- 借方: 入金先の口座
  INSERT INTO debits (
    journal_id, element_type, account_id, item_name, amount, user_id
  ) VALUES (
    new_journal_id,
    ELEMENT_ASSETS,
    asset_account_id,
    NULL,
    amount,
    user_id
  );

  -- 貸方: 収益科目（資産・負債以外の貸方は、支払方法を持たない）
  INSERT INTO credits (
    journal_id, element_type, payment_method_type, account_id, amount, user_id
  ) VALUES (
    new_journal_id,
    ELEMENT_REVENUE,
    NO_PAYMENT_METHOD,
    revenue_account_id,
    amount,
    user_id
  );

  RETURN new_journal_id;
END;
$$;
