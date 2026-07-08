CREATE OR REPLACE FUNCTION insert_journal_entry(
  journal_data JSONB
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
  new_journal_id INT;
  v_journal_date DATE;
  v_store_name TEXT;
  v_user_id INT;
  v_sum_debit INT := 0;
  v_sum_credit INT := 0;
BEGIN
  -- 1. 借方の合計金額を計算
  SELECT COALESCE(SUM(amount), 0) INTO v_sum_debit
  FROM jsonb_to_recordset(journal_data->'debits') AS x(amount INT);

  -- 2. 貸方の合計金額を計算
  SELECT COALESCE(SUM(amount), 0) INTO v_sum_credit
  FROM jsonb_to_recordset(journal_data->'credits') AS x(amount INT);

  -- 3. 貸借不一致のバリデーション（金額が合わなければエラーを投げる）
  IF v_sum_debit <> v_sum_credit THEN
    RAISE EXCEPTION '貸借の合計金額が一致しません。借方: %, 貸方: %', v_sum_debit, v_sum_credit
      USING ERRCODE = '23514'; -- Check Violation のエラーコードを指定
  END IF;

  -- 金額が一致している場合のみ、以降のインサート処理が実行されます
  -- 4. 親情報の抽出
  v_journal_date := (journal_data->>'date')::DATE;
  v_store_name   := (journal_data->>'store_name')::TEXT;
  v_user_id      := (journal_data->>'user_id')::INT;

  -- 5. 親テーブルへのインサート
  INSERT INTO journals (date, user_id, created_at)
  VALUES (v_date, v_user_id, NOW())
  RETURNING id INTO new_journal_id;
  -- 5. 親仕訳データを作成
  INSERT INTO journals (
    journal_dt, store_name, user_id
  ) VALUES (
    v_journal_date,
    v_store_name,
    v_user_id
  )
  RETURNING id INTO new_journal_id;

  -- 6. 借方（debits）のインサート
  INSERT INTO debits (
    journal_id, element_type, account_id, item_name, amount, user_id
  )
  SELECT
    new_journal_id,
    element_type,
    account_id,
    item_name,
    amount,
    v_user_id
  FROM jsonb_to_recordset(journal_data->'debits')
    AS debits(
         element_type INT,
         account_id INT,
         item_name TEXT,
         amount INT
       );

  -- 7. 貸方（credits）のインサート
  INSERT INTO credits (
    journal_id, element_type, payment_method_type, account_id, amount, user_id
  )
  SELECT
    new_journal_id,
    element_type,
    payment_method_type,
    account_id,
    amount,
    v_user_id
  FROM jsonb_to_recordset(journal_data->'credits')
    AS credits(
         element_type INT,
         payment_method_type INT,
         account_id INT,
         amount INT
       );

  RETURN new_journal_id;
END;
$$;
