CREATE OR REPLACE FUNCTION generate_opening_asset_balance_journal(
  journal_date DATE,
  asset_type INT,
  asset_account_id INT,
  amount INT,
  user_id INT
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
  journal_record journals%ROWTYPE;
  asset_account_record asset_accounts%ROWTYPE;
  equity_account_record equity_accounts%ROWTYPE;
  new_id INT;
  ITEM_NAME CONSTANT TEXT := '開始残高';
  EQUITY_NAME CONSTANT TEXT := '元入金';
  EQUITY_ELEMENT_NO CONSTANT INT := 3;
BEGIN
  -- 預入する銀行の資産科目を取得
  -- 親仕訳データの店名に使用するため
  SELECT *
    INTO asset_account_record
    FROM asset_accounts
   WHERE id = asset_account_id
  ;

  -- 親仕訳データを作成
  INSERT INTO journals (
    journal_dt, store_name, user_id
  ) VALUES (
    journal_date,
    asset_account_record.name,
    user_id
  )
  RETURNING id INTO new_id;

  -- 預入借方データを作成
  INSERT INTO debits (
    journal_id, element_type, account_id, item_name, amount, user_id
  ) VALUES (
    new_id,
    asset_type,
    asset_account_id,
    ITEM_NAME,
    amount,
    user_id
  );

  -- 元入金科目を取得
  -- 預入貸方データの科目に設定するため
  SELECT *
    INTO equity_account_record
    FROM equity_accounts
   WHERE name = EQUITY_NAME
  ;

  -- 預入貸方データを作成
  -- 元入金固定
  INSERT INTO credits (
    journal_id, element_type, payment_method_type, account_id, amount, user_id
  ) VALUES (
    new_id,
    EQUITY_ELEMENT_NO,
    0,
    equity_account_record.id,
    amount,
    user_id
  );

  -- 親仕訳データの id を返却
  RETURN new_id;
END;
$$;
