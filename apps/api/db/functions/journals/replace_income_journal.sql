CREATE OR REPLACE FUNCTION replace_income_journal(
  journal_id INT,
  journal_date DATE,
  asset_account_id INT,
  revenue_account_id INT,
  amount INT,
  description TEXT,
  user_id INT
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
  v_new_journal_id INT;
  v_occurrence_entry_ids BIGINT[];
  v_occurrence_dates DATE[];
  ELEMENT_REVENUE CONSTANT INT := 4;
BEGIN
  -- 他ユーザーの仕訳と存在しない仕訳は区別しない。
  -- 同時に修正・削除されないよう、行をロックする
  PERFORM 1
     FROM journals j
    WHERE j.id = replace_income_journal.journal_id
      AND j.user_id = replace_income_journal.user_id
      FOR UPDATE
  ;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'journal not found: %', journal_id;
  END IF;

  -- 修正できるのは収入の仕訳（貸方がすべて収益）だけ
  IF NOT EXISTS (
       SELECT 1
         FROM credits c
        WHERE c.journal_id = replace_income_journal.journal_id
     )
     OR EXISTS (
       SELECT 1
         FROM credits c
        WHERE c.journal_id = replace_income_journal.journal_id
          AND c.element_type <> ELEMENT_REVENUE
     ) THEN
    RAISE EXCEPTION 'journal is not an income journal: %', journal_id;
  END IF;

  -- 決まった支払いから登録した仕訳なら、その回の記録を新しい仕訳に付け替える。
  -- 記録は元の仕訳の削除で一緒に消える（外部キーの ON DELETE CASCADE）ので、先に控えておく
  SELECT ARRAY_AGG(o.recurring_entry_id), ARRAY_AGG(o.scheduled_date)
    INTO v_occurrence_entry_ids, v_occurrence_dates
    FROM recurring_entry_occurrences o
   WHERE o.journal_id = replace_income_journal.journal_id
  ;

  -- 元の仕訳を消して、登録と同じ確認をしながら作り直す。
  -- どちらかで失敗すると、関数全体が取り消されて元の仕訳が残る
  PERFORM delete_journal(replace_income_journal.journal_id, replace_income_journal.user_id);

  v_new_journal_id := create_income_journal(
    journal_date, asset_account_id, revenue_account_id, amount, description, user_id
  );

  IF v_occurrence_entry_ids IS NOT NULL THEN
    INSERT INTO recurring_entry_occurrences (recurring_entry_id, scheduled_date, journal_id)
    SELECT x.entry_id, x.scheduled_date, v_new_journal_id
      FROM UNNEST(v_occurrence_entry_ids, v_occurrence_dates) AS x(entry_id, scheduled_date)
    ;
  END IF;

  RETURN v_new_journal_id;
END;
$$;
