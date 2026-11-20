CREATE OR REPLACE FUNCTION replace_journal_entry(journal_id INT, journal_data JSONB)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id INT;
  ELEMENT_EXPENSES CONSTANT INT := 5;
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

  -- 元の仕訳（と引き落とし仕訳）を消して、登録と同じ確認をしながら作り直す。
  -- どちらかで失敗すると、関数全体が取り消されて元の仕訳が残る
  PERFORM delete_journal(replace_journal_entry.journal_id, v_user_id);

  RETURN insert_journal_entry(journal_data);
END;
$$;
