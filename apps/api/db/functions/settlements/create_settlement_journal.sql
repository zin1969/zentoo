CREATE OR REPLACE FUNCTION create_settlement_journal(
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
  v_receivable_name TEXT;
  v_to_type INT;
  v_difference INT;
  new_journal_id INT;
  ELEMENT_ASSETS CONSTANT INT := 1;
  ELEMENT_REVENUE CONSTANT INT := 4;
  ELEMENT_EXPENSES CONSTANT INT := 5;
  ASSET_TYPE_RECEIVABLE CONSTANT INT := 6;
BEGIN
  -- 消し込む額（立替金から減らす額）
  IF settled_amount <= 0 THEN
    RAISE EXCEPTION 'settled amount must be greater than 0';
  END IF;

  -- 受け取った額。全額おごりになったときは 0
  IF received_amount < 0 THEN
    RAISE EXCEPTION 'received amount must not be negative';
  END IF;

  -- 立替金は本人の種別「立替金」の口座。他ユーザーの口座と存在しない口座は区別しない
  SELECT aa.name
    INTO v_receivable_name
    FROM asset_accounts aa
   WHERE aa.id = create_settlement_journal.receivable_account_id
     AND aa.user_id = create_settlement_journal.user_id
     AND aa.asset_type = ASSET_TYPE_RECEIVABLE
  ;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'receivable account not found: %', receivable_account_id;
  END IF;

  -- 入金先は本人の口座（立替金の口座は除く）。受け取りが無ければ要らない
  IF received_amount > 0 THEN
    SELECT aa.asset_type
      INTO v_to_type
      FROM asset_accounts aa
     WHERE aa.id = create_settlement_journal.to_account_id
       AND aa.user_id = create_settlement_journal.user_id
       AND aa.asset_type <> ASSET_TYPE_RECEIVABLE
    ;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'to account not found: %', to_account_id;
    END IF;
  END IF;

  -- 差額 = 消し込む額 - 受け取った額。少なく受け取ったら費用、多く受け取ったら収益にする
  v_difference := settled_amount - received_amount;

  IF v_difference > 0 AND NOT EXISTS (
    SELECT 1
      FROM expense_accounts ea
     WHERE ea.id = create_settlement_journal.difference_account_id
       AND (ea.user_id IS NULL OR ea.user_id = create_settlement_journal.user_id)
  ) THEN
    RAISE EXCEPTION 'difference account not found: %', difference_account_id;
  END IF;

  IF v_difference < 0 AND NOT EXISTS (
    SELECT 1
      FROM revenue_accounts ra
     WHERE ra.id = create_settlement_journal.difference_account_id
       AND (ra.user_id IS NULL OR ra.user_id = create_settlement_journal.user_id)
  ) THEN
    RAISE EXCEPTION 'difference account not found: %', difference_account_id;
  END IF;

  INSERT INTO journals (
    journal_dt, store_name, user_id
  ) VALUES (
    journal_date,
    COALESCE(NULLIF(BTRIM(description), ''), '精算 ' || v_receivable_name),
    user_id
  )
  RETURNING id INTO new_journal_id;

  -- 借方: 入金先（受け取った額）
  IF received_amount > 0 THEN
    INSERT INTO debits (
      journal_id, element_type, account_id, item_name, amount, user_id
    ) VALUES (
      new_journal_id, ELEMENT_ASSETS, to_account_id, NULL, received_amount, user_id
    );
  END IF;

  -- 借方: 費用（少なく受け取った分。会社に認められない分・おごり）
  IF v_difference > 0 THEN
    INSERT INTO debits (
      journal_id, element_type, account_id, item_name, amount, user_id
    ) VALUES (
      new_journal_id, ELEMENT_EXPENSES, difference_account_id, NULL, v_difference, user_id
    );
  END IF;

  -- 貸方: 立替金（消し込む額）。支払い方法は口座の種別
  INSERT INTO credits (
    journal_id, element_type, payment_method_type, account_id, amount, user_id
  ) VALUES (
    new_journal_id, ELEMENT_ASSETS, ASSET_TYPE_RECEIVABLE, receivable_account_id, settled_amount, user_id
  );

  -- 貸方: 収益（多く受け取った分）
  IF v_difference < 0 THEN
    INSERT INTO credits (
      journal_id, element_type, payment_method_type, account_id, amount, user_id
    ) VALUES (
      new_journal_id, ELEMENT_REVENUE, 0, difference_account_id, -v_difference, user_id
    );
  END IF;

  RETURN new_journal_id;
END;
$$;
