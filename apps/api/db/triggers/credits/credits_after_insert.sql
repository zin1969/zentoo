CREATE OR REPLACE FUNCTION credits_after_insert_fn()
RETURNS trigger AS $$
DECLARE
  v_credit_card credit_cards%ROWTYPE;
  v_original_journal journals%ROWTYPE;
  v_bank_asset_type INT;
  v_payment_date DATE;
  v_direct_debit_journal_id BIGINT;
  v_item_names TEXT;
  ELEMENT_ASSETS CONSTANT INT := 1;
  ELEMENT_LIABILITIES CONSTANT INT := 2;
  PAYMENT_METHOD_CREDIT_CARD CONSTANT INT := 3;
  DIRECT_DEBIT_PAYMENT_DATE_SETTING CONSTANT TEXT := 'app.direct_debit_payment_date';
BEGIN
  -- カード払い以外は何もしない
  IF NOT (NEW.element_type = ELEMENT_LIABILITIES AND NEW.payment_method_type = PAYMENT_METHOD_CREDIT_CARD) THEN
    RETURN NEW;
  END IF;

  -- 締日・支払日・引き落とし口座を持つカード設定を取得する
  SELECT cc.*
    INTO v_credit_card
    FROM credit_cards cc
   WHERE cc.liability_account_id = NEW.account_id
     AND cc.user_id = NEW.user_id
  ;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'credit_card setting not found: liability_account_id=%', NEW.account_id;
  END IF;

  -- 引き落とし口座の種別を、貸方の支払方法にそのまま使うため取得する
  SELECT aa.asset_type
    INTO v_bank_asset_type
    FROM asset_accounts aa
   WHERE aa.id = v_credit_card.bank_account_id
  ;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'credit_card setting not found: bank_account_id=%', v_credit_card.bank_account_id;
  END IF;

  SELECT j.*
    INTO v_original_journal
    FROM journals j
   WHERE j.id = NEW.journal_id
  ;

  -- 引き落とし日が呼び出し元（開始負債の登録）から指定されていれば、それを使う。
  -- 指定がなければ、カードの締日・支払日と仕訳日から計算する
  v_payment_date := NULLIF(current_setting(DIRECT_DEBIT_PAYMENT_DATE_SETTING, TRUE), '')::DATE;

  IF v_payment_date IS NULL THEN
    v_payment_date := get_payment_date(
      v_credit_card.cutoff_day,
      v_credit_card.payment_day,
      v_original_journal.journal_dt
    );
  END IF;

  -- 引き落とし仕訳を作成する
  INSERT INTO journals (
    journal_dt, store_name, user_id
  ) VALUES (
    v_payment_date,
    v_original_journal.store_name,
    v_original_journal.user_id
  )
  RETURNING id INTO v_direct_debit_journal_id;

  -- カード払いの仕訳と引き落とし仕訳を紐付ける
  INSERT INTO direct_debit_journals (
    original_id, direct_debit_id, user_id
  ) VALUES (
    v_original_journal.id,
    v_direct_debit_journal_id,
    v_original_journal.user_id
  );

  -- 貸方: 引き落とし口座
  INSERT INTO credits (
    journal_id, element_type, payment_method_type, account_id, amount, user_id
  ) VALUES (
    v_direct_debit_journal_id,
    ELEMENT_ASSETS,
    v_bank_asset_type,
    v_credit_card.bank_account_id,
    NEW.amount,
    v_original_journal.user_id
  );

  -- 元の仕訳の項目名を集約して、借方の項目名にする
  SELECT STRING_AGG(d.item_name, ',' ORDER BY d.id)
    INTO v_item_names
    FROM debits d
   WHERE d.journal_id = v_original_journal.id
  ;

  -- 借方: カード（負債）の支払い
  INSERT INTO debits (
    journal_id, element_type, account_id, item_name, amount, user_id
  ) VALUES (
    v_direct_debit_journal_id,
    ELEMENT_LIABILITIES,
    NEW.account_id,
    v_item_names,
    NEW.amount,
    v_original_journal.user_id
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS credits_after_insert ON credits;

CREATE TRIGGER credits_after_insert
AFTER INSERT ON credits
FOR EACH ROW
EXECUTE FUNCTION credits_after_insert_fn();
