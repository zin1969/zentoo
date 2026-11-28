CREATE OR REPLACE FUNCTION create_transfer_journal(
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
  v_to_type INT;
  v_from_type INT;
  v_payment_method INT;
  v_label TEXT;
  new_journal_id INT;
  ELEMENT_ASSETS CONSTANT INT := 1;
  ELEMENT_LIABILITIES CONSTANT INT := 2;
  ASSET_TYPE_CASH CONSTANT INT := 1;
  ASSET_TYPE_DEPOSIT CONSTANT INT := 2;
  ASSET_TYPE_E_MONEY CONSTANT INT := 3;
  ASSET_TYPE_RECEIVABLE CONSTANT INT := 6;
  LIABILITY_TYPE_CREDIT_CARD CONSTANT INT := 3;
  PAYMENT_METHOD_CREDIT_CARD CONSTANT INT := 3;
BEGIN
  IF amount <= 0 THEN
    RAISE EXCEPTION 'amount must be greater than 0';
  END IF;

  -- 入れる先は本人の口座。他ユーザーの口座と存在しない口座は区別しない
  SELECT aa.asset_type
    INTO v_to_type
    FROM asset_accounts aa
   WHERE aa.id = create_transfer_journal.to_account_id
     AND aa.user_id = create_transfer_journal.user_id
  ;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'to account not found: %', to_account_id;
  END IF;

  IF from_element_type = ELEMENT_ASSETS THEN
    -- 口座から: 支払方法は口座の種別（現金・預金・電子マネー）
    SELECT aa.asset_type
      INTO v_from_type
      FROM asset_accounts aa
     WHERE aa.id = create_transfer_journal.from_account_id
       AND aa.user_id = create_transfer_journal.user_id
    ;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'from account not found: %', from_account_id;
    END IF;

    -- 立替金から返してもらうのは精算（create_settlement_journal）で登録する。差額を費用・収益にできるようにするため
    IF v_from_type = ASSET_TYPE_RECEIVABLE THEN
      RAISE EXCEPTION 'receivable must be settled: %', from_account_id;
    END IF;

    IF from_account_id = to_account_id THEN
      RAISE EXCEPTION 'from and to accounts must differ: %', from_account_id;
    END IF;

    v_payment_method := v_from_type;
  ELSIF from_element_type = ELEMENT_LIABILITIES THEN
    -- クレジットカードから: 入れられるのは電子マネーだけ（チャージ）
    IF NOT EXISTS (
      SELECT 1
        FROM liability_accounts la
       WHERE la.id = create_transfer_journal.from_account_id
         AND la.user_id = create_transfer_journal.user_id
         AND la.liability_type = LIABILITY_TYPE_CREDIT_CARD
    ) THEN
      RAISE EXCEPTION 'from account not found: %', from_account_id;
    END IF;

    IF v_to_type <> ASSET_TYPE_E_MONEY THEN
      RAISE EXCEPTION 'credit card can only charge e-money: %', to_account_id;
    END IF;

    v_payment_method := PAYMENT_METHOD_CREDIT_CARD;
  ELSE
    RAISE EXCEPTION 'from account not found: %', from_account_id;
  END IF;

  -- 摘要は通帳に出るので、空なら組み合わせから決める
  v_label := CASE
    WHEN v_to_type = ASSET_TYPE_E_MONEY THEN 'チャージ'
    WHEN v_from_type = ASSET_TYPE_DEPOSIT AND v_to_type = ASSET_TYPE_CASH THEN '引き出し'
    WHEN v_from_type = ASSET_TYPE_CASH AND v_to_type = ASSET_TYPE_DEPOSIT THEN '預入'
    ELSE '振替'
  END;

  INSERT INTO journals (
    journal_dt, store_name, user_id
  ) VALUES (
    journal_date,
    COALESCE(NULLIF(BTRIM(description), ''), v_label),
    user_id
  )
  RETURNING id INTO new_journal_id;

  -- 借方: 入れる先の口座
  INSERT INTO debits (
    journal_id, element_type, account_id, item_name, amount, user_id
  ) VALUES (
    new_journal_id,
    ELEMENT_ASSETS,
    to_account_id,
    NULL,
    amount,
    user_id
  );

  -- 貸方: 出す元。カードからのチャージは、credits_after_insert トリガーが引き落とし仕訳を作る
  INSERT INTO credits (
    journal_id, element_type, payment_method_type, account_id, amount, user_id
  ) VALUES (
    new_journal_id,
    from_element_type,
    v_payment_method,
    from_account_id,
    amount,
    user_id
  );

  RETURN new_journal_id;
END;
$$;
