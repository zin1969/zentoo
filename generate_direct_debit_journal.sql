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

  IF cutoff_day = 31 THEN
    cutoff_date := get_last_date_of_month(y, m);
  ELSE
    cutoff_date := MAKE_DATE(y, m, cutoff_day);
  END IF;

  IF journal_date <= cutoff_date THEN
    payment_date := MAKE_DATE(y, m, payment_day) + INTERVAL '1 month';
  ELSE
    payment_date := MAKE_DATE(y, m, payment_day) + INTERVAL '2 month';
  END IF;

  payment_date := get_next_business_day(payment_date);

  RETURN payment_date;
END;
$$;

CREATE OR REPLACE FUNCTION generate_direct_journal()
RETURNS TRIGGER AS $$
DECLARE
  credit_card_record credit_cards%ROWTYPE;
  original_journal_record journals%ROWTYPE;
  payment_date DATE;
  new_id INT;
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

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
