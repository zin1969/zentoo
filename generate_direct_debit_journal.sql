CREATE OR REPLACE FUNCTION get_last_date_of_month(
  y INT,
  m INT
)
RETURNS DATE
LANGUAGE plpgsql AS $$
DECLARE
  first_date_of_next_month DATE;
  last_date_of_month DATE;
BEGIN
  first_date_of_next_month := MAKE_DATE(y, m, 1) + INTERVAL '1 month';
  last_date_of_month := first_date_of_next_month - INTERVAL '1 day';

  RETURN last_date_of_month;
END;
$$;

CREATE OR REPLACE FUNCTION get_payment_date(
  cutoff_day INT,
  payment_day INT,
  journal_date DATE
)
RETURNS DATE
LANGUAGE plpgsql AS $$
DECLARE
  y INT;
  m INT;
  cutoff_date DATE;
  payment_date DATE;
BEGIN
  y := EXTRACT(YEAR FROM journal_date)::int;
  m := EXTRACT(MONTH FROM journal_date)::int;

  -- 締日が月末の場合は月毎の末日に調整
  IF cutoff_day = 31 THEN
    cutoff_date := get_last_date_of_month(y, m);
  ELSE
    cutoff_date := MAKE_DATE(y, m, cutoff_day);
  END IF;

  -- 締日と支払日の関係で算出方法を変更
  IF cutoff_day < payment_day THEN
    IF journal_date <= cutoff_date THEN
      payment_date := MAKE_DATE(y, m, payment_day);
    ELSE
      payment_date := MAKE_DATE(y, m, payment_day) + INTERVAL '1 month';
    END IF;
  ELSE
    IF journal_date <= cutoff_date THEN
      payment_date := MAKE_DATE(y, m, payment_day) + INTERVAL '1 month';
    ELSE
      payment_date := MAKE_DATE(y, m, payment_day) + INTERVAL '2 month';
    END IF;
  END IF;

  payment_date := get_next_business_day(payment_date);

  RETURN payment_date;
END;
$$;

CREATE OR REPLACE FUNCTION generate_direct_debit_journal()
RETURNS TRIGGER AS $$
DECLARE
  credit_card_record credit_cards%ROWTYPE;
  original_journal_record journals%ROWTYPE;
  payment_date DATE;
  new_id INT;
  new_item_name TEXT;
BEGIN
  -- カード支払い以外は処理をしない
  -- アーリーリターン（早期離脱）
  IF NOT (NEW.type = 2 AND NEW.payment_method_type = 3) THEN
    RETURN NEW;
  END IF;

  -- クレジットカード情報を取得
  -- 口座振替日の算出に使用
  SELECT *
    INTO credit_card_record
    FROM credit_cards
   WHERE liability_account_id = NEW.account_id
  ;

  -- 仕訳レコードを取得
  SELECT *
    INTO original_journal_record
    FROM journals
   WHERE id = NEW.journal_id
  ;

  -- 口座振替日を算出
  payment_date := get_payment_date(
    credit_card_record.cutoff_day,
    credit_card_record.payment_day,
    original_journal_record.journal_dt
  );

  -- 口座振替用 journal レコードを生成
  INSERT INTO journals (
    journal_dt, store_name, user_id
  ) VALUES (
    payment_date,
    original_journal_record.store_name,
    original_journal_record.user_id
  )
  RETURNING id INTO new_id;

  -- クレジット支払と口座振替の journal レコードを紐付けるデータを作成
  INSERT INTO direct_debit_journals (
    original_id, direct_debit_id, user_id
  ) VALUES (
    original_journal_record.id,
    new_id,
    original_journal_record.user_id
  );

  -- 口座振替借方仕訳を作成
  INSERT INTO credits (
    journal_id, type, payment_method_type, account_id, amount, user_id
  ) VALUES (
    new_id,
    1,
    2,
    credit_card_record.bank_account_id,
    NEW.amount,
    original_journal_record.user_id
  );

  -- 項目名を集約する
  -- 口座振替貸方仕訳に使用
  SELECT STRING_AGG(item_name, ',')
    INTO new_item_name
    FROM debits
   WHERE journal_id = original_journal_record.id
  ;

  -- 口座振替貸方仕訳を作成
  INSERT INTO debits (
    journal_id, type, account_id, item_name, amount, user_id
  ) VALUES (
    new_id,
    2,
    NEW.account_id,
    new_item_name,
    NEW.amount,
    original_journal_record.user_id
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
