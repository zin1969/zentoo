CREATE OR REPLACE FUNCTION generate_make_a_cash_deposit_journal(
  journal_date DATE,
  asset_account_id INT,
  amount INT,
  user_id INT
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
  journal_record journals%ROWTYPE;
  bank_account_record asset_accounts%ROWTYPE;
  cash_account_record asset_accounts%ROWTYPE;
  new_id INT;
  ITEM_NAME CONSTANT TEXT := '預入';
BEGIN
  -- 預入する銀行の資産科目を取得
  -- 親仕訳データの店名に使用するため
  SELECT *
    INTO bank_account_record
    FROM asset_accounts
   WHERE id = asset_account_id
  ;

  -- 親仕訳データを作成
  INSERT INTO journals (
    journal_dt, store_name, user_id
  ) VALUES (
    journal_date,
    bank_account_record.name,
    user_id
  )
  RETURNING id INTO new_id;

  -- 預入借方データを作成
  INSERT INTO debits (
    journal_id, type, account_id, item_name, amount, user_id
  ) VALUES (
    new_id,
    1,
    asset_account_id,
    ITEM_NAME,
    amount,
    user_id
  );

  -- 現金資産科目を取得
  -- 預入貸方データの科目に設定するため
  SELECT *
    INTO cash_account_record
    FROM asset_accounts
   WHERE type = 1
  ;

  -- 預入貸方データを作成
  -- 現金固定
  INSERT INTO credits (
    journal_id, type, payment_method_type, account_id, amount, user_id
  ) VALUES (
    new_id,
    1,
    1,
    cash_account_record.id,
    amount,
    user_id
  );

  -- 親仕訳データの id を返却
  RETURN new_id;
END;
$$;
