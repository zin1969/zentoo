CREATE OR REPLACE FUNCTION delete_journal(journal_id INT, user_id INT)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
  v_journal_ids BIGINT[];
  v_deleted_count INT;
BEGIN
  -- 他ユーザーの仕訳と存在しない仕訳は区別しない。
  -- 同時に修正・削除されないよう、行をロックする
  PERFORM 1
     FROM journals j
    WHERE j.id = delete_journal.journal_id
      AND j.user_id = delete_journal.user_id
      FOR UPDATE
  ;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'journal not found: %', journal_id;
  END IF;

  -- 引き落とし仕訳はカード払いから自動で作られたもの。単独で消すと、カードの負債だけが残ってしまう
  IF EXISTS (
    SELECT 1
      FROM direct_debit_journals ddj
     WHERE ddj.direct_debit_id = delete_journal.journal_id
  ) THEN
    RAISE EXCEPTION 'direct debit journal cannot be deleted: %', journal_id;
  END IF;

  -- 元の仕訳と、そのカード払いで自動で作られた引き落とし仕訳をまとめて消す
  v_journal_ids := ARRAY[delete_journal.journal_id::BIGINT] || ARRAY(
    SELECT ddj.direct_debit_id
      FROM direct_debit_journals ddj
     WHERE ddj.original_id = delete_journal.journal_id
  );

  DELETE FROM direct_debit_journals ddj
   WHERE ddj.original_id = delete_journal.journal_id
  ;

  DELETE FROM debits d
   WHERE d.journal_id = ANY(v_journal_ids)
  ;

  DELETE FROM credits c
   WHERE c.journal_id = ANY(v_journal_ids)
  ;

  DELETE FROM journals j
   WHERE j.id = ANY(v_journal_ids)
  ;

  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

  RETURN v_deleted_count;
END;
$$;
