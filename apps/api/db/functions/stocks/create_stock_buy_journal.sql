CREATE OR REPLACE FUNCTION create_stock_buy_journal(
  journal_date DATE,
  stock_account_id INT,
  securities_account_id INT,
  shares INT,
  amount INT,
  user_id INT
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
  v_stock_name TEXT;
  new_journal_id INT;
  ELEMENT_ASSETS CONSTANT INT := 1;
  ASSET_TYPE_SECURITIES CONSTANT INT := 4;
  ASSET_TYPE_INVESTMENT CONSTANT INT := 5;
BEGIN
  IF shares <= 0 THEN
    RAISE EXCEPTION 'shares must be greater than 0';
  END IF;

  -- 手数料も取得額に含めるので、金額は証券口座から出ていった額
  IF amount <= 0 THEN
    RAISE EXCEPTION 'amount must be greater than 0';
  END IF;

  -- 銘柄は本人の種別「投資」の口座。他ユーザーの口座と存在しない口座は区別しない
  SELECT aa.name
    INTO v_stock_name
    FROM asset_accounts aa
   WHERE aa.id = create_stock_buy_journal.stock_account_id
     AND aa.user_id = create_stock_buy_journal.user_id
     AND aa.asset_type = ASSET_TYPE_INVESTMENT
  ;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'stock account not found: %', stock_account_id;
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM asset_accounts aa
     WHERE aa.id = create_stock_buy_journal.securities_account_id
       AND aa.user_id = create_stock_buy_journal.user_id
       AND aa.asset_type = ASSET_TYPE_SECURITIES
  ) THEN
    RAISE EXCEPTION 'securities account not found: %', securities_account_id;
  END IF;

  -- 売りの取得額（移動平均）は、売った日までの売買から決まる。
  -- 後の日付の売りがあるところに前の日付で登録すると、その売りの取得額が合わなくなる
  IF get_last_stock_sale_date(stock_account_id) > journal_date THEN
    RAISE EXCEPTION 'later stock sale exists: %', stock_account_id;
  END IF;

  INSERT INTO journals (
    journal_dt, store_name, user_id
  ) VALUES (
    journal_date,
    '買い ' || v_stock_name,
    user_id
  )
  RETURNING id INTO new_journal_id;

  -- 借方: 銘柄（株数が増える）
  INSERT INTO debits (
    journal_id, element_type, account_id, item_name, amount, shares, user_id
  ) VALUES (
    new_journal_id,
    ELEMENT_ASSETS,
    stock_account_id,
    NULL,
    amount,
    shares,
    user_id
  );

  -- 貸方: 証券口座（預り金）
  INSERT INTO credits (
    journal_id, element_type, payment_method_type, account_id, amount, user_id
  ) VALUES (
    new_journal_id,
    ELEMENT_ASSETS,
    ASSET_TYPE_SECURITIES,
    securities_account_id,
    amount,
    user_id
  );

  RETURN new_journal_id;
END;
$$;
