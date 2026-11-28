CREATE OR REPLACE FUNCTION create_stock_sell_journal(
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
  v_held_shares BIGINT;
  v_held_cost BIGINT;
  v_cost INT;
  v_gain_account_id BIGINT;
  v_loss_account_id BIGINT;
  new_journal_id INT;
  ELEMENT_ASSETS CONSTANT INT := 1;
  ELEMENT_REVENUE CONSTANT INT := 4;
  ELEMENT_EXPENSES CONSTANT INT := 5;
  ASSET_TYPE_SECURITIES CONSTANT INT := 4;
  ASSET_TYPE_INVESTMENT CONSTANT INT := 5;
  GAIN_ACCOUNT_NAME CONSTANT TEXT := '株式売却益';
  LOSS_ACCOUNT_NAME CONSTANT TEXT := '株式売却損';
BEGIN
  IF shares <= 0 THEN
    RAISE EXCEPTION 'shares must be greater than 0';
  END IF;

  -- 金額は証券口座に入った額（手数料・税金を引いたあと）
  IF amount <= 0 THEN
    RAISE EXCEPTION 'amount must be greater than 0';
  END IF;

  -- 銘柄は本人の種別「投資」の口座。他ユーザーの口座と存在しない口座は区別しない
  SELECT aa.name
    INTO v_stock_name
    FROM asset_accounts aa
   WHERE aa.id = create_stock_sell_journal.stock_account_id
     AND aa.user_id = create_stock_sell_journal.user_id
     AND aa.asset_type = ASSET_TYPE_INVESTMENT
  ;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'stock account not found: %', stock_account_id;
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM asset_accounts aa
     WHERE aa.id = create_stock_sell_journal.securities_account_id
       AND aa.user_id = create_stock_sell_journal.user_id
       AND aa.asset_type = ASSET_TYPE_SECURITIES
  ) THEN
    RAISE EXCEPTION 'securities account not found: %', securities_account_id;
  END IF;

  -- 後の日付の売りがあると、その売りの取得額（移動平均）が合わなくなる
  IF get_last_stock_sale_date(stock_account_id) > journal_date THEN
    RAISE EXCEPTION 'later stock sale exists: %', stock_account_id;
  END IF;

  -- 売った日（含む）までの株数と取得額
  SELECT h.shares, h.cost
    INTO v_held_shares, v_held_cost
    FROM get_stock_holdings(create_stock_sell_journal.user_id, journal_date) h
   WHERE h.account_id = create_stock_sell_journal.stock_account_id
  ;

  IF NOT FOUND OR v_held_shares < shares THEN
    RAISE EXCEPTION 'insufficient shares: %', stock_account_id;
  END IF;

  -- 減らす取得額は移動平均（取得額 ÷ 株数）× 売った株数。全部売るときは端数を残さないよう取得額をそのまま減らす
  v_cost := CASE
    WHEN shares = v_held_shares THEN v_held_cost
    ELSE ROUND(v_held_cost::NUMERIC * shares / v_held_shares)
  END;

  IF v_cost <= 0 THEN
    RAISE EXCEPTION 'stock cost must be greater than 0: %', stock_account_id;
  END IF;

  -- 売却益・売却損の科目は元入金と同じく名前で探す（共通科目を優先し、無ければ本人の科目を使う）
  IF amount > v_cost THEN
    SELECT ra.id
      INTO v_gain_account_id
      FROM revenue_accounts ra
     WHERE ra.name = GAIN_ACCOUNT_NAME
       AND (ra.user_id IS NULL OR ra.user_id = create_stock_sell_journal.user_id)
     ORDER BY ra.user_id NULLS FIRST, ra.id
     LIMIT 1
    ;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'stock gain account not found: %', GAIN_ACCOUNT_NAME;
    END IF;
  ELSIF amount < v_cost THEN
    SELECT ea.id
      INTO v_loss_account_id
      FROM expense_accounts ea
     WHERE ea.name = LOSS_ACCOUNT_NAME
       AND (ea.user_id IS NULL OR ea.user_id = create_stock_sell_journal.user_id)
     ORDER BY ea.user_id NULLS FIRST, ea.id
     LIMIT 1
    ;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'stock loss account not found: %', LOSS_ACCOUNT_NAME;
    END IF;
  END IF;

  INSERT INTO journals (
    journal_dt, store_name, user_id
  ) VALUES (
    journal_date,
    '売り ' || v_stock_name,
    user_id
  )
  RETURNING id INTO new_journal_id;

  -- 借方: 証券口座（預り金）に入った額
  INSERT INTO debits (
    journal_id, element_type, account_id, item_name, amount, user_id
  ) VALUES (
    new_journal_id,
    ELEMENT_ASSETS,
    securities_account_id,
    NULL,
    amount,
    user_id
  );

  -- 借方: 売却損（取得額より安く売ったとき）
  IF v_loss_account_id IS NOT NULL THEN
    INSERT INTO debits (
      journal_id, element_type, account_id, item_name, amount, user_id
    ) VALUES (
      new_journal_id,
      ELEMENT_EXPENSES,
      v_loss_account_id,
      NULL,
      v_cost - amount,
      user_id
    );
  END IF;

  -- 貸方: 銘柄（株数と取得額が減る）
  INSERT INTO credits (
    journal_id, element_type, payment_method_type, account_id, amount, shares, user_id
  ) VALUES (
    new_journal_id,
    ELEMENT_ASSETS,
    ASSET_TYPE_INVESTMENT,
    stock_account_id,
    v_cost,
    shares,
    user_id
  );

  -- 貸方: 売却益（取得額より高く売ったとき）
  IF v_gain_account_id IS NOT NULL THEN
    INSERT INTO credits (
      journal_id, element_type, payment_method_type, account_id, amount, user_id
    ) VALUES (
      new_journal_id,
      ELEMENT_REVENUE,
      0,
      v_gain_account_id,
      amount - v_cost,
      user_id
    );
  END IF;

  RETURN new_journal_id;
END;
$$;
