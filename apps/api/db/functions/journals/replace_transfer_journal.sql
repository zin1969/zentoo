CREATE OR REPLACE FUNCTION replace_transfer_journal(
  journal_id INT,
  journal_date DATE,
  from_element_type INT,
  from_account_id INT,
  to_account_id INT,
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
  ELEMENT_ASSETS CONSTANT INT := 1;
  ELEMENT_LIABILITIES CONSTANT INT := 2;
  PAYMENT_METHOD_CREDIT_CARD CONSTANT INT := 3;
BEGIN
  -- 他ユーザーの仕訳と存在しない仕訳は区別しない。
  -- 同時に修正・削除されないよう、行をロックする
  PERFORM 1
     FROM journals j
    WHERE j.id = replace_transfer_journal.journal_id
      AND j.user_id = replace_transfer_journal.user_id
      FOR UPDATE
  ;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'journal not found: %', journal_id;
  END IF;

  -- 修正できるのは振替の仕訳だけ: 借方が口座 1 つ、貸方が口座かクレジットカード 1 つ。
  -- 引き落とし仕訳（借方がカード）は、この形にならないので含まれない
  IF (
       SELECT COUNT(*)
         FROM debits d
        WHERE d.journal_id = replace_transfer_journal.journal_id
     ) <> 1
     OR NOT EXISTS (
       SELECT 1
         FROM debits d
        WHERE d.journal_id = replace_transfer_journal.journal_id
          AND d.element_type = ELEMENT_ASSETS
     )
     OR (
       SELECT COUNT(*)
         FROM credits c
        WHERE c.journal_id = replace_transfer_journal.journal_id
     ) <> 1
     OR NOT EXISTS (
       SELECT 1
         FROM credits c
        WHERE c.journal_id = replace_transfer_journal.journal_id
          AND (
            c.element_type = ELEMENT_ASSETS
            OR (c.element_type = ELEMENT_LIABILITIES AND c.payment_method_type = PAYMENT_METHOD_CREDIT_CARD)
          )
     ) THEN
    RAISE EXCEPTION 'journal is not a transfer journal: %', journal_id;
  END IF;

  -- 決まった振替の回の記録は、仕訳を消すと一緒に消える（ON DELETE CASCADE）ので、先に控えて新しい仕訳に付け直す
  SELECT ARRAY_AGG(o.recurring_entry_id), ARRAY_AGG(o.scheduled_date)
    INTO v_occurrence_entry_ids, v_occurrence_dates
    FROM recurring_entry_occurrences o
   WHERE o.journal_id = replace_transfer_journal.journal_id
  ;

  -- 元の仕訳（とカードからのチャージの引き落とし仕訳）を消して、登録と同じ確認をしながら作り直す。
  -- どちらかで失敗すると、関数全体が取り消されて元の仕訳が残る
  PERFORM delete_journal(replace_transfer_journal.journal_id, replace_transfer_journal.user_id);

  v_new_journal_id := create_transfer_journal(
    journal_date, from_element_type, from_account_id, to_account_id, amount, description, user_id
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
