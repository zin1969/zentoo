CREATE OR REPLACE FUNCTION create_opening_liability_balance_journal(
  journal_date DATE,
  liability_account_id INT,
  amount INT,
  payment_date DATE,
  user_id INT
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
  liability_account_record liability_accounts%ROWTYPE;
  equity_account_record equity_accounts%ROWTYPE;
  new_journal_id INT;
  OPENING_ITEM_NAME CONSTANT TEXT := '開始残高';
  EQUITY_NAME CONSTANT TEXT := '元入金';
  ELEMENT_LIABILITIES CONSTANT INT := 2;
  ELEMENT_EQUITY CONSTANT INT := 3;
  LIABILITY_TYPE_CREDIT_CARD CONSTANT INT := 3;
  PAYMENT_METHOD_CREDIT_CARD CONSTANT INT := 3;
  DIRECT_DEBIT_PAYMENT_DATE_SETTING CONSTANT TEXT := 'app.direct_debit_payment_date';
BEGIN
  IF amount <= 0 THEN
    RAISE EXCEPTION 'amount must be greater than 0';
  END IF;

  -- 引き落とし日が開始日より前のものは、すでに支払い済みで未払いではない
  IF payment_date < journal_date THEN
    RAISE EXCEPTION 'payment date must not be before journal date: payment_date=%, journal_date=%', payment_date, journal_date;
  END IF;

  -- カード（負債科目）を取得
  -- 存在しない科目、他ユーザーの科目、カードではない科目は区別しない
  SELECT *
    INTO liability_account_record
    FROM liability_accounts
   WHERE id = liability_account_id
     AND liability_accounts.user_id = create_opening_liability_balance_journal.user_id
     AND liability_accounts.liability_type = LIABILITY_TYPE_CREDIT_CARD
  ;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'liability_account not found: %', liability_account_id;
  END IF;

  -- 同じカード・同じ引き落とし日の開始負債が既に登録されている場合はエラー
  IF EXISTS (
    SELECT 1
      FROM debits od
      JOIN credits oc ON oc.journal_id = od.journal_id
      JOIN direct_debit_journals ddj ON ddj.original_id = od.journal_id
      JOIN journals dj ON dj.id = ddj.direct_debit_id
     WHERE od.element_type = ELEMENT_EQUITY
       AND od.item_name = OPENING_ITEM_NAME
       AND od.user_id = create_opening_liability_balance_journal.user_id
       AND oc.element_type = ELEMENT_LIABILITIES
       AND oc.account_id = liability_account_id
       AND dj.journal_dt = payment_date
  ) THEN
    RAISE EXCEPTION 'opening liability already exists: liability_account_id=%, payment_date=%', liability_account_id, payment_date;
  END IF;

  -- 元入金科目を取得（共通科目を優先し、無ければ本人の科目を使う）
  SELECT *
    INTO equity_account_record
    FROM equity_accounts
   WHERE name = EQUITY_NAME
     AND (equity_accounts.user_id IS NULL
          OR equity_accounts.user_id = create_opening_liability_balance_journal.user_id)
   ORDER BY equity_accounts.user_id NULLS FIRST
   LIMIT 1
  ;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'equity account not found: %', EQUITY_NAME;
  END IF;

  -- 親仕訳データを作成
  INSERT INTO journals (
    journal_dt, store_name, user_id
  ) VALUES (
    journal_date,
    liability_account_record.name,
    user_id
  )
  RETURNING id INTO new_journal_id;

  -- 借方: 元入金（開始資産の貸方の逆）
  INSERT INTO debits (
    journal_id, element_type, account_id, item_name, amount, user_id
  ) VALUES (
    new_journal_id,
    ELEMENT_EQUITY,
    equity_account_record.id,
    OPENING_ITEM_NAME,
    amount,
    user_id
  );

  -- 貸方: カード（負債）
  -- credits_after_insert トリガーが引き落とし仕訳を作る。その日付に、指定された引き落とし日を使わせる
  PERFORM set_config(DIRECT_DEBIT_PAYMENT_DATE_SETTING, payment_date::TEXT, TRUE);

  INSERT INTO credits (
    journal_id, element_type, payment_method_type, account_id, amount, user_id
  ) VALUES (
    new_journal_id,
    ELEMENT_LIABILITIES,
    PAYMENT_METHOD_CREDIT_CARD,
    liability_account_id,
    amount,
    user_id
  );

  -- 同じトランザクションの後続の仕訳に影響しないよう、指定を消す
  PERFORM set_config(DIRECT_DEBIT_PAYMENT_DATE_SETTING, '', TRUE);

  RETURN new_journal_id;
END;
$$;
