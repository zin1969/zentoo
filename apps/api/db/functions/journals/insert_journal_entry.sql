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
  v_entry RECORD;
  v_available BOOLEAN;
  ELEMENT_ASSETS CONSTANT INT := 1;
  ELEMENT_LIABILITIES CONSTANT INT := 2;
  ELEMENT_EQUITY CONSTANT INT := 3;
  ELEMENT_EXPENSES CONSTANT INT := 5;
BEGIN
  -- 1. 借方の合計金額を計算
  SELECT COALESCE(SUM(amount), 0) INTO v_sum_debit
  FROM jsonb_to_recordset(journal_data->'debits') AS x(amount INT);

  -- 2. 貸方の合計金額を計算
  SELECT COALESCE(SUM(amount), 0) INTO v_sum_credit
  FROM jsonb_to_recordset(journal_data->'credits') AS x(amount INT);

  -- 3. 貸借不一致のバリデーション（金額が合わなければエラーを投げる）
  IF v_sum_debit <> v_sum_credit THEN
    RAISE EXCEPTION 'unbalance debit and credit. debit: %, credit: %', v_sum_debit, v_sum_credit
      USING ERRCODE = 'P0001'; -- Check Violation のエラーコードを指定
  END IF;

  -- 金額が一致している場合のみ、以降のインサート処理が実行されます
  -- 4. 親情報の抽出
  v_journal_date := (journal_data->>'date')::DATE;
  v_store_name   := (journal_data->>'store_name')::TEXT;
  v_user_id      := (journal_data->>'user_id')::INT;

  -- 4.5 借方・貸方の科目が使えるか確認する
  -- 資産・負債科目は本人のもののみ。費用・資本科目は共通科目（user_id IS NULL）も使える。
  -- 他人の科目と存在しない科目は区別しない。収益科目はテーブルが無いため常に使えない
  FOR v_entry IN
    SELECT d.element_type, d.account_id
      FROM jsonb_to_recordset(journal_data->'debits') AS d(element_type INT, account_id INT)
    UNION ALL
    SELECT c.element_type, c.account_id
      FROM jsonb_to_recordset(journal_data->'credits') AS c(element_type INT, account_id INT)
  LOOP
    v_available := CASE v_entry.element_type
      WHEN ELEMENT_ASSETS THEN EXISTS (
        SELECT 1 FROM asset_accounts a
         WHERE a.id = v_entry.account_id AND a.user_id = v_user_id
      )
      WHEN ELEMENT_LIABILITIES THEN EXISTS (
        SELECT 1 FROM liability_accounts a
         WHERE a.id = v_entry.account_id AND a.user_id = v_user_id
      )
      WHEN ELEMENT_EQUITY THEN EXISTS (
        SELECT 1 FROM equity_accounts a
         WHERE a.id = v_entry.account_id AND (a.user_id IS NULL OR a.user_id = v_user_id)
      )
      WHEN ELEMENT_EXPENSES THEN EXISTS (
        SELECT 1 FROM expense_accounts a
         WHERE a.id = v_entry.account_id AND (a.user_id IS NULL OR a.user_id = v_user_id)
      )
      ELSE FALSE
    END;

    IF NOT v_available THEN
      RAISE EXCEPTION 'account not found: element_type=%, account_id=%', v_entry.element_type, v_entry.account_id;
    END IF;
  END LOOP;

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
