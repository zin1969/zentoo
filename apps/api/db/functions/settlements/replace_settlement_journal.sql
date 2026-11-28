CREATE OR REPLACE FUNCTION replace_settlement_journal(
  journal_id INT,
  journal_date DATE,
  receivable_account_id INT,
  settled_amount INT,
  received_amount INT,
  to_account_id INT,
  difference_account_id INT,
  description TEXT,
  user_id INT
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
  v_new_journal_id INT;
  ELEMENT_ASSETS CONSTANT INT := 1;
  ASSET_TYPE_RECEIVABLE CONSTANT INT := 6;
BEGIN
  -- 他ユーザーの仕訳と存在しない仕訳は区別しない。
  -- 同時に修正・削除されないよう、行をロックする
  PERFORM 1
     FROM journals j
    WHERE j.id = replace_settlement_journal.journal_id
      AND j.user_id = replace_settlement_journal.user_id
      FOR UPDATE
  ;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'journal not found: %', journal_id;
  END IF;

  -- 修正できるのは精算の仕訳だけ: 貸方に立替金が 1 つある。
  -- 立替金が貸方に来るのは精算だけ（振替では立替金から出せず、お買い物の支払い方法にも出さない）
  IF (
       SELECT COUNT(*)
         FROM credits c
        WHERE c.journal_id = replace_settlement_journal.journal_id
          AND c.element_type = ELEMENT_ASSETS
          AND c.payment_method_type = ASSET_TYPE_RECEIVABLE
     ) <> 1 THEN
    RAISE EXCEPTION 'journal is not a settlement journal: %', journal_id;
  END IF;

  -- 元の仕訳を消して、登録と同じ確認をしながら作り直す。
  -- どちらかで失敗すると、関数全体が取り消されて元の仕訳が残る
  PERFORM delete_journal(replace_settlement_journal.journal_id, replace_settlement_journal.user_id);

  v_new_journal_id := create_settlement_journal(
    journal_date, receivable_account_id, settled_amount, received_amount,
    to_account_id, difference_account_id, description, user_id
  );

  RETURN v_new_journal_id;
END;
$$;
