CREATE OR REPLACE FUNCTION update_direct_debit_date(journal_id INT, payment_date DATE, user_id INT)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
  v_original_date DATE;
BEGIN
  -- 他ユーザーの仕訳と存在しない仕訳は区別しない。
  -- 同時に修正・削除されないよう、行をロックする
  PERFORM 1
     FROM journals j
    WHERE j.id = update_direct_debit_date.journal_id
      AND j.user_id = update_direct_debit_date.user_id
      FOR UPDATE
  ;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'journal not found: %', journal_id;
  END IF;

  -- 日付だけを変えられるのは、カード払いから自動で作られた引き落とし仕訳だけ
  SELECT oj.journal_dt
    INTO v_original_date
    FROM direct_debit_journals ddj
    JOIN journals oj ON oj.id = ddj.original_id
   WHERE ddj.direct_debit_id = update_direct_debit_date.journal_id
  ;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'journal is not a direct debit journal: %', journal_id;
  END IF;

  -- 買う前（開始負債なら開始日より前）に引き落とされることはない。
  -- それ以外は明細の日付をそのまま使い、営業日にはずらさない
  IF payment_date < v_original_date THEN
    RAISE EXCEPTION 'payment date must not be before journal date: payment_date=%, journal_date=%', payment_date, v_original_date;
  END IF;

  UPDATE journals j
     SET journal_dt = update_direct_debit_date.payment_date
   WHERE j.id = update_direct_debit_date.journal_id
  ;

  -- 元のお買い物を修正したときに、この日付を引き継げるよう記録する
  UPDATE direct_debit_journals ddj
     SET payment_date_overridden = TRUE
   WHERE ddj.direct_debit_id = update_direct_debit_date.journal_id
  ;

  RETURN journal_id;
END;
$$;
