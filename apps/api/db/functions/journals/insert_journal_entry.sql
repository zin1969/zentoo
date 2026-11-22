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
  v_debit RECORD;
  v_debit_id BIGINT;
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

  -- 4.6 明細ごとのタグ（tag_ids）を確認する。タグは本人のものだけ、費用の明細にだけ付けられる。
  -- 他人のタグと存在しないタグは区別しない
  IF EXISTS (
    SELECT 1
      FROM jsonb_array_elements(journal_data->'debits') AS e(value)
     CROSS JOIN LATERAL jsonb_array_elements_text(
       CASE WHEN jsonb_typeof(e.value->'tag_ids') = 'array' THEN e.value->'tag_ids' ELSE '[]'::JSONB END
     ) AS t(tag_id)
     WHERE NOT EXISTS (
       SELECT 1 FROM tags tg WHERE tg.id = t.tag_id::BIGINT AND tg.user_id = v_user_id
     )
  ) THEN
    RAISE EXCEPTION 'tag not found';
  END IF;

  IF EXISTS (
    SELECT 1
      FROM jsonb_array_elements(journal_data->'debits') AS e(value)
     WHERE jsonb_typeof(e.value->'tag_ids') = 'array'
       AND jsonb_array_length(e.value->'tag_ids') > 0
       AND (e.value->>'element_type')::INT IS DISTINCT FROM ELEMENT_EXPENSES
  ) THEN
    RAISE EXCEPTION 'tags are only for expense debits';
  END IF;

  -- 4.7 外税で登録した明細の税率・税抜の金額は、お買い物の費用の明細にだけ持たせる（表示のため。金額は amount の税込）
  IF EXISTS (
    SELECT 1
      FROM jsonb_array_elements(journal_data->'debits') AS e(value)
     WHERE e.value->>'tax_rate' IS NOT NULL
       AND (e.value->>'element_type')::INT IS DISTINCT FROM ELEMENT_EXPENSES
  ) THEN
    RAISE EXCEPTION 'tax is only for expense debits';
  END IF;

  -- 5. 親仕訳データを作成
  INSERT INTO journals (
    journal_dt, store_name, user_id
  ) VALUES (
    v_journal_date,
    v_store_name,
    v_user_id
  )
  RETURNING id INTO new_journal_id;

  -- 6. 借方（debits）のインサート。明細ごとのタグも入れるので、1 行ずつ送られた順に入れる
  FOR v_debit IN
    SELECT e.value
      FROM jsonb_array_elements(journal_data->'debits') WITH ORDINALITY AS e(value, ord)
     ORDER BY e.ord
  LOOP
    INSERT INTO debits (
      journal_id, element_type, account_id, item_name, amount, tax_rate, tax_excluded_amount, user_id
    ) VALUES (
      new_journal_id,
      (v_debit.value->>'element_type')::INT,
      (v_debit.value->>'account_id')::INT,
      v_debit.value->>'item_name',
      (v_debit.value->>'amount')::INT,
      (v_debit.value->>'tax_rate')::INT,
      (v_debit.value->>'tax_excluded_amount')::INT,
      v_user_id
    )
    RETURNING id INTO v_debit_id;

    INSERT INTO debit_tags (debit_id, tag_id)
    SELECT DISTINCT v_debit_id, t.tag_id::BIGINT
      FROM jsonb_array_elements_text(
        CASE WHEN jsonb_typeof(v_debit.value->'tag_ids') = 'array' THEN v_debit.value->'tag_ids' ELSE '[]'::JSONB END
      ) AS t(tag_id);
  END LOOP;

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
