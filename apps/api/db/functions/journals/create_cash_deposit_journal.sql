CREATE OR REPLACE FUNCTION create_cash_deposit_journal(
  journal_date DATE,
  bank_account_id INT,
  amount INT,
  user_id INT
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
  bank_account_record asset_accounts%ROWTYPE;
  v_cash_account_count INT;
  v_cash_account_id BIGINT;
  new_journal_id INT;
  DEPOSIT_ITEM_NAME CONSTANT TEXT := '預入';
  ELEMENT_ASSETS CONSTANT INT := 1;
  ASSET_TYPE_CASH CONSTANT INT := 1;
  ASSET_TYPE_DEPOSIT CONSTANT INT := 2;
  PAYMENT_METHOD_CASH CONSTANT INT := 1;
BEGIN
  IF amount <= 0 THEN
    RAISE EXCEPTION 'amount must be greater than 0';
  END IF;

  -- 預け入れ先の預金口座を取得（親仕訳の店名に使う）
  -- 存在しない科目、他ユーザーの科目、預金口座ではない科目は区別しない
  SELECT *
    INTO bank_account_record
    FROM asset_accounts
   WHERE id = bank_account_id
     AND asset_accounts.user_id = create_cash_deposit_journal.user_id
     AND asset_accounts.asset_type = ASSET_TYPE_DEPOSIT
  ;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'asset_account not found: %', bank_account_id;
  END IF;

  -- 貸方の現金科目は、ユーザーの現金科目が 1 つだけのときに限って、それを使う
  SELECT COUNT(*), MIN(aa.id)
    INTO v_cash_account_count, v_cash_account_id
    FROM asset_accounts aa
   WHERE aa.user_id = create_cash_deposit_journal.user_id
     AND aa.asset_type = ASSET_TYPE_CASH
  ;

  IF v_cash_account_count <> 1 THEN
    RAISE EXCEPTION 'cash account not determined: count=%', v_cash_account_count;
  END IF;

  -- 親仕訳データを作成
  INSERT INTO journals (
    journal_dt, store_name, user_id
  ) VALUES (
    journal_date,
    bank_account_record.name,
    user_id
  )
  RETURNING id INTO new_journal_id;

  -- 借方: 預け入れ先の預金口座
  INSERT INTO debits (
    journal_id, element_type, account_id, item_name, amount, user_id
  ) VALUES (
    new_journal_id,
    ELEMENT_ASSETS,
    bank_account_id,
    DEPOSIT_ITEM_NAME,
    amount,
    user_id
  );

  -- 貸方: 現金
  INSERT INTO credits (
    journal_id, element_type, payment_method_type, account_id, amount, user_id
  ) VALUES (
    new_journal_id,
    ELEMENT_ASSETS,
    PAYMENT_METHOD_CASH,
    v_cash_account_id,
    amount,
    user_id
  );

  RETURN new_journal_id;
END;
$$;
