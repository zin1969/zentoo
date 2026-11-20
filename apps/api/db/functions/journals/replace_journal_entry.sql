CREATE OR REPLACE FUNCTION replace_journal_entry(journal_id INT, journal_data JSONB)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id INT;
  v_new_journal_id INT;
  v_carry_payment_date DATE;
  v_carry_card_id INT;
  ELEMENT_EXPENSES CONSTANT INT := 5;
  ELEMENT_LIABILITIES CONSTANT INT := 2;
  PAYMENT_METHOD_CREDIT_CARD CONSTANT INT := 3;
  DIRECT_DEBIT_PAYMENT_DATE_SETTING CONSTANT TEXT := 'app.direct_debit_payment_date';
BEGIN
  v_user_id := (journal_data->>'user_id')::INT;

  -- 他ユーザーの仕訳と存在しない仕訳は区別しない。
  -- 同時に修正・削除されないよう、行をロックする
  PERFORM 1
     FROM journals j
    WHERE j.id = replace_journal_entry.journal_id
      AND j.user_id = v_user_id
      FOR UPDATE
  ;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'journal not found: %', journal_id;
  END IF;

  -- 引き落とし仕訳はカード払いから自動で作られたもの。元のカード払いの仕訳を直せば作り直される
  IF EXISTS (
    SELECT 1
      FROM direct_debit_journals ddj
     WHERE ddj.direct_debit_id = replace_journal_entry.journal_id
  ) THEN
    RAISE EXCEPTION 'direct debit journal cannot be updated: %', journal_id;
  END IF;

  -- 修正できるのはお買い物の仕訳（借方がすべて費用）だけ。
  -- 開始残高や預け入れは画面の項目が違うので、削除して登録し直す
  IF NOT EXISTS (
       SELECT 1
         FROM debits d
        WHERE d.journal_id = replace_journal_entry.journal_id
     )
     OR EXISTS (
       SELECT 1
         FROM debits d
        WHERE d.journal_id = replace_journal_entry.journal_id
          AND d.element_type <> ELEMENT_EXPENSES
     ) THEN
    RAISE EXCEPTION 'journal is not a shopping journal: %', journal_id;
  END IF;

  -- 修正後も、お買い物の仕訳のままにする
  IF EXISTS (
    SELECT 1
      FROM jsonb_to_recordset(journal_data->'debits') AS x(element_type INT)
     WHERE x.element_type IS DISTINCT FROM ELEMENT_EXPENSES
  ) THEN
    RAISE EXCEPTION 'shopping journal must debit expenses only';
  END IF;

  -- 引き落とし日を手で変えていたら、その日とカードを覚えておく。
  -- カード払いが 1 つだけの仕訳に限る（複数あると、どの引き落としの日付か決められない）
  SELECT dj.journal_dt, dd.account_id
    INTO v_carry_payment_date, v_carry_card_id
    FROM direct_debit_journals ddj
    JOIN journals dj ON dj.id = ddj.direct_debit_id
    JOIN debits dd ON dd.journal_id = dj.id
   WHERE ddj.original_id = replace_journal_entry.journal_id
     AND ddj.payment_date_overridden
     AND (
       SELECT COUNT(*)
         FROM direct_debit_journals other
        WHERE other.original_id = replace_journal_entry.journal_id
     ) = 1
  ;

  -- 修正後も同じカード 1 枚での支払いで、買った日が引き落とし日より後にならないときだけ引き継ぐ。
  -- それ以外は、締め日・支払日からの自動の計算に戻す
  IF v_carry_payment_date IS NOT NULL AND NOT (
    (journal_data->>'date')::DATE <= v_carry_payment_date
    AND (
      SELECT COUNT(*) = 1 AND BOOL_AND(x.account_id = v_carry_card_id)
        FROM jsonb_to_recordset(journal_data->'credits')
          AS x(element_type INT, payment_method_type INT, account_id INT)
       WHERE x.element_type = ELEMENT_LIABILITIES
         AND x.payment_method_type = PAYMENT_METHOD_CREDIT_CARD
    )
  ) THEN
    v_carry_payment_date := NULL;
  END IF;

  -- 元の仕訳（と引き落とし仕訳）を消して、登録と同じ確認をしながら作り直す。
  -- どちらかで失敗すると、関数全体が取り消されて元の仕訳が残る
  PERFORM delete_journal(replace_journal_entry.journal_id, v_user_id);

  IF v_carry_payment_date IS NOT NULL THEN
    -- credits_after_insert トリガーに、引き落とし日として使わせる
    PERFORM set_config(DIRECT_DEBIT_PAYMENT_DATE_SETTING, v_carry_payment_date::TEXT, TRUE);
  END IF;

  v_new_journal_id := insert_journal_entry(journal_data);

  IF v_carry_payment_date IS NOT NULL THEN
    -- 同じトランザクションの後続の仕訳に影響しないよう、指定を消す
    PERFORM set_config(DIRECT_DEBIT_PAYMENT_DATE_SETTING, '', TRUE);

    -- 引き継いだ日も手で変えた日なので、次に修正したときも引き継ぐ
    UPDATE direct_debit_journals ddj
       SET payment_date_overridden = TRUE
     WHERE ddj.original_id = v_new_journal_id
    ;
  END IF;

  RETURN v_new_journal_id;
END;
$$;
