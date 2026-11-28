CREATE OR REPLACE FUNCTION create_opening_stock_balance_journal(
  journal_date DATE,
  stock_account_id INT,
  shares INT,
  amount INT,
  user_id INT
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
  new_journal_id INT;
  ELEMENT_ASSETS CONSTANT INT := 1;
  ASSET_TYPE_INVESTMENT CONSTANT INT := 5;
BEGIN
  IF shares <= 0 THEN
    RAISE EXCEPTION 'shares must be greater than 0';
  END IF;

  -- 株数を持てるのは銘柄（本人の種別「投資」の口座）だけ。
  -- 他ユーザーの口座と存在しない口座は、開始資産と同じく区別しない
  IF NOT EXISTS (
    SELECT 1
      FROM asset_accounts aa
     WHERE aa.id = create_opening_stock_balance_journal.stock_account_id
       AND aa.user_id = create_opening_stock_balance_journal.user_id
  ) THEN
    RAISE EXCEPTION 'asset_account not found: %', stock_account_id;
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM asset_accounts aa
     WHERE aa.id = create_opening_stock_balance_journal.stock_account_id
       AND aa.asset_type = ASSET_TYPE_INVESTMENT
  ) THEN
    RAISE EXCEPTION 'shares require an investment account: %', stock_account_id;
  END IF;

  -- 後の日付の売りがあると、その売りの取得額（移動平均）が合わなくなる
  IF get_last_stock_sale_date(stock_account_id) > journal_date THEN
    RAISE EXCEPTION 'later stock sale exists: %', stock_account_id;
  END IF;

  -- 金額（株数 × 平均取得単価）の確認・重複の確認・元入金は、開始資産の登録と同じ
  new_journal_id := create_opening_asset_balance_journal(
    journal_date, ELEMENT_ASSETS, stock_account_id, amount, user_id
  );

  UPDATE debits d
     SET shares = create_opening_stock_balance_journal.shares
   WHERE d.journal_id = new_journal_id
     AND d.element_type = ELEMENT_ASSETS
  ;

  RETURN new_journal_id;
END;
$$;
