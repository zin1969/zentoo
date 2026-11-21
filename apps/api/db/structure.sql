SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: create_cash_deposit_journal(date, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_cash_deposit_journal(journal_date date, bank_account_id integer, amount integer, user_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  bank_account_record asset_accounts%ROWTYPE;
  v_cash_account_count INT;
  v_cash_account_id BIGINT;
  new_journal_id INT;
  DEPOSIT_ITEM_NAME CONSTANT TEXT := '預入';
  ELEMENT_ASSETS CONSTANT INT := 1;
  ASSET_TYPE_CASH CONSTANT INT := 1;
  ASSET_TYPE_DEPOSIT CONSTANT INT := 2;
  PAYMENT_METHOD_CASH CONSTANT INT := 1;
BEGIN
  IF amount <= 0 THEN
    RAISE EXCEPTION 'amount must be greater than 0';
  END IF;

  -- 預け入れ先の預金口座を取得（親仕訳の店名に使う）
  -- 存在しない科目、他ユーザーの科目、預金口座ではない科目は区別しない
  SELECT *
    INTO bank_account_record
    FROM asset_accounts
   WHERE id = bank_account_id
     AND asset_accounts.user_id = create_cash_deposit_journal.user_id
     AND asset_accounts.asset_type = ASSET_TYPE_DEPOSIT
  ;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'asset_account not found: %', bank_account_id;
  END IF;

  -- 貸方の現金科目は、ユーザーの現金科目が 1 つだけのときに限って、それを使う
  SELECT COUNT(*), MIN(aa.id)
    INTO v_cash_account_count, v_cash_account_id
    FROM asset_accounts aa
   WHERE aa.user_id = create_cash_deposit_journal.user_id
     AND aa.asset_type = ASSET_TYPE_CASH
  ;

  IF v_cash_account_count <> 1 THEN
    RAISE EXCEPTION 'cash account not determined: count=%', v_cash_account_count;
  END IF;

  -- 親仕訳データを作成
  INSERT INTO journals (
    journal_dt, store_name, user_id
  ) VALUES (
    journal_date,
    bank_account_record.name,
    user_id
  )
  RETURNING id INTO new_journal_id;

  -- 借方: 預け入れ先の預金口座
  INSERT INTO debits (
    journal_id, element_type, account_id, item_name, amount, user_id
  ) VALUES (
    new_journal_id,
    ELEMENT_ASSETS,
    bank_account_id,
    DEPOSIT_ITEM_NAME,
    amount,
    user_id
  );

  -- 貸方: 現金
  INSERT INTO credits (
    journal_id, element_type, payment_method_type, account_id, amount, user_id
  ) VALUES (
    new_journal_id,
    ELEMENT_ASSETS,
    PAYMENT_METHOD_CASH,
    v_cash_account_id,
    amount,
    user_id
  );

  RETURN new_journal_id;
END;
$$;


--
-- Name: create_opening_asset_balance_journal(date, integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_opening_asset_balance_journal(journal_date date, asset_type integer, asset_account_id integer, amount integer, user_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  journal_record journals%ROWTYPE;
  asset_account_record asset_accounts%ROWTYPE;
  equity_account_record equity_accounts%ROWTYPE;
  new_journal_id INT;
  OPENING_ITEM_NAME CONSTANT TEXT := '開始残高';
  EQUITY_NAME CONSTANT TEXT := '元入金';
  EQUITY_ELEMENT_NO CONSTANT INT := 3;
BEGIN
  -- 開始資産額が 0 円未満はエラー
  IF amount <= 0 THEN
    RAISE EXCEPTION 'amount must be greater than 0';
  END IF;

  -- 開始資産科目を取得
  SELECT *
    INTO asset_account_record
    FROM asset_accounts
   WHERE id = asset_account_id
     AND asset_accounts.user_id = create_opening_asset_balance_journal.user_id
  ;

  -- 資産科目が存在しない、または他ユーザーの科目の場合のガードコード（存在有無を区別しない）
  IF NOT FOUND THEN
    RAISE EXCEPTION 'asset_account not found: %', asset_account_id;
  END IF;

  -- 同じ資産科目の開始残高が既に登録されている場合はエラー
  IF EXISTS (
    SELECT 1
      FROM debits d
     WHERE d.element_type = asset_type
       AND d.account_id = asset_account_id
       AND d.item_name = OPENING_ITEM_NAME
  ) THEN
    RAISE EXCEPTION 'opening asset already exists: %', asset_account_id;
  END IF;

  -- 元入金科目を取得
  -- 預入貸方データの科目に設定するため（共通科目を優先し、無ければ本人の科目を使う）
  SELECT *
    INTO equity_account_record
    FROM equity_accounts
   WHERE name = EQUITY_NAME
     AND (equity_accounts.user_id IS NULL
          OR equity_accounts.user_id = create_opening_asset_balance_journal.user_id)
   ORDER BY equity_accounts.user_id NULLS FIRST
   LIMIT 1
  ;

  -- 元入金科目が存在しない場合のガードコード
  IF NOT FOUND THEN
    RAISE EXCEPTION 'equity account not found: %', EQUITY_NAME;
  END IF;

  -- 親仕訳データを作成
  INSERT INTO journals (
    journal_dt, store_name, user_id
  ) VALUES (
    journal_date,
    asset_account_record.name,
    user_id
  )
  RETURNING id INTO new_journal_id;

  -- 預入借方データを作成
  INSERT INTO debits (
    journal_id, element_type, account_id, item_name, amount, user_id
  ) VALUES (
    new_journal_id,
    asset_type,
    asset_account_id,
    OPENING_ITEM_NAME,
    amount,
    user_id
  );

  -- 預入貸方データを作成
  -- 元入金固定
  INSERT INTO credits (
    journal_id, element_type, payment_method_type, account_id, amount, user_id
  ) VALUES (
    new_journal_id,
    EQUITY_ELEMENT_NO,
    0,
    equity_account_record.id,
    amount,
    user_id
  );

  -- 親仕訳データの id を返却
  RETURN new_journal_id;
END;
$$;


--
-- Name: create_opening_liability_balance_journal(date, integer, integer, date, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_opening_liability_balance_journal(journal_date date, liability_account_id integer, amount integer, payment_date date, user_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: credits_after_insert_fn(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.credits_after_insert_fn() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: delete_journal(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_journal(journal_id integer, user_id integer) RETURNS integer
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


--
-- Name: get_account_balances(integer, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_account_balances(user_id integer, as_of_date date) RETURNS TABLE(element_type integer, account_id bigint, account_name text, balance bigint)
    LANGUAGE plpgsql
    AS $$
DECLARE
  ELEMENT_ASSETS CONSTANT INT := 1;
  ELEMENT_LIABILITIES CONSTANT INT := 2;
BEGIN
  -- 指定日（含む）までの仕訳から、資産・負債科目ごとの借方合計・貸方合計を求める
  -- 資産の残高は「借方 - 貸方」、負債の残高（未払いの額）は「貸方 - 借方」
  RETURN QUERY
  WITH movements AS (
    SELECT d.element_type, d.account_id, d.amount::BIGINT AS debit_amount, 0::BIGINT AS credit_amount
      FROM debits d
      JOIN journals j ON j.id = d.journal_id
     WHERE j.user_id = get_account_balances.user_id
       AND j.journal_dt <= as_of_date
       AND d.element_type IN (ELEMENT_ASSETS, ELEMENT_LIABILITIES)
    UNION ALL
    SELECT c.element_type, c.account_id, 0::BIGINT, c.amount::BIGINT
      FROM credits c
      JOIN journals j ON j.id = c.journal_id
     WHERE j.user_id = get_account_balances.user_id
       AND j.journal_dt <= as_of_date
       AND c.element_type IN (ELEMENT_ASSETS, ELEMENT_LIABILITIES)
  ), totals AS (
    SELECT m.element_type, m.account_id,
           SUM(m.debit_amount) AS debit_total,
           SUM(m.credit_amount) AS credit_total
      FROM movements m
     GROUP BY m.element_type, m.account_id
  )
  SELECT ELEMENT_ASSETS, aa.id::BIGINT, aa.name,
         (COALESCE(t.debit_total, 0) - COALESCE(t.credit_total, 0))::BIGINT
    FROM asset_accounts aa
    LEFT JOIN totals t ON t.element_type = ELEMENT_ASSETS AND t.account_id = aa.id
   WHERE aa.user_id = get_account_balances.user_id
  UNION ALL
  SELECT ELEMENT_LIABILITIES, la.id::BIGINT, la.name,
         (COALESCE(t.credit_total, 0) - COALESCE(t.debit_total, 0))::BIGINT
    FROM liability_accounts la
    LEFT JOIN totals t ON t.element_type = ELEMENT_LIABILITIES AND t.account_id = la.id
   WHERE la.user_id = get_account_balances.user_id
  ORDER BY 1, 2;
END;
$$;


--
-- Name: get_bank_account_ledger(integer, integer, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_bank_account_ledger(user_id integer, asset_account_id integer, from_date date, to_date date) RETURNS TABLE(row_type text, entry_date date, card_account_id bigint, description text, deposit bigint, withdrawal bigint, balance bigint, journal_ids bigint[])
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_carried_over BIGINT;
  ELEMENT_ASSETS CONSTANT INT := 1;
  ELEMENT_LIABILITIES CONSTANT INT := 2;
  ASSET_TYPE_DEPOSIT CONSTANT INT := 2;
  ROW_CARRIED_OVER CONSTANT TEXT := 'carried_over';
  ROW_JOURNAL CONSTANT TEXT := 'journal';
  ROW_CARD_PAYMENT CONSTANT TEXT := 'card_payment';
BEGIN
  -- 通帳を見られるのは本人の預金口座だけ。他ユーザーの口座、預金ではない口座は区別しない
  IF NOT EXISTS (
    SELECT 1
      FROM asset_accounts aa
     WHERE aa.id = get_bank_account_ledger.asset_account_id
       AND aa.user_id = get_bank_account_ledger.user_id
       AND aa.asset_type = ASSET_TYPE_DEPOSIT
  ) THEN
    RAISE EXCEPTION 'asset_account not found: %', asset_account_id;
  END IF;

  -- 期間の初日の前日までの残高（繰越）。資産なので「借方 - 貸方」
  SELECT COALESCE(SUM(mv.mv_deposit - mv.mv_withdrawal), 0)::BIGINT
    INTO v_carried_over
    FROM (
      SELECT d.amount::BIGINT AS mv_deposit, 0::BIGINT AS mv_withdrawal
        FROM debits d
        JOIN journals j ON j.id = d.journal_id
       WHERE j.user_id = get_bank_account_ledger.user_id
         AND j.journal_dt < from_date
         AND d.element_type = ELEMENT_ASSETS
         AND d.account_id = get_bank_account_ledger.asset_account_id
      UNION ALL
      SELECT 0::BIGINT, c.amount::BIGINT
        FROM credits c
        JOIN journals j ON j.id = c.journal_id
       WHERE j.user_id = get_bank_account_ledger.user_id
         AND j.journal_dt < from_date
         AND c.element_type = ELEMENT_ASSETS
         AND c.account_id = get_bank_account_ledger.asset_account_id
    ) mv;

  RETURN QUERY
  WITH movements AS (
    -- 借方（入金）。摘要は明細の項目名（開始残高・預入など）、無ければ店舗名
    SELECT j.id AS mv_journal_id, j.journal_dt AS mv_date,
           COALESCE(NULLIF(d.item_name, ''), j.store_name) AS mv_description,
           d.amount::BIGINT AS mv_deposit, 0::BIGINT AS mv_withdrawal
      FROM debits d
      JOIN journals j ON j.id = d.journal_id
     WHERE j.user_id = get_bank_account_ledger.user_id
       AND j.journal_dt BETWEEN from_date AND to_date
       AND d.element_type = ELEMENT_ASSETS
       AND d.account_id = get_bank_account_ledger.asset_account_id
    UNION ALL
    -- 貸方（出金）
    SELECT j.id, j.journal_dt, j.store_name, 0::BIGINT, c.amount::BIGINT
      FROM credits c
      JOIN journals j ON j.id = c.journal_id
     WHERE j.user_id = get_bank_account_ledger.user_id
       AND j.journal_dt BETWEEN from_date AND to_date
       AND c.element_type = ELEMENT_ASSETS
       AND c.account_id = get_bank_account_ledger.asset_account_id
  ), tagged AS (
    -- カードの引き落とし仕訳には、どのカードの引き落としかと、元のお買い物の仕訳を付ける
    SELECT mv.*, card.card_id AS mv_card_id, ddj.original_id AS mv_original_id
      FROM movements mv
      LEFT JOIN direct_debit_journals ddj ON ddj.direct_debit_id = mv.mv_journal_id
      LEFT JOIN LATERAL (
        SELECT dd.account_id::BIGINT AS card_id
          FROM debits dd
         WHERE dd.journal_id = mv.mv_journal_id
           AND dd.element_type = ELEMENT_LIABILITIES
         LIMIT 1
      ) card ON ddj.id IS NOT NULL
  ), grouped AS (
    -- 本物の通帳と同じく、カードの引き落としは同じ日・同じカードの分を 1 行にまとめる
    SELECT CASE WHEN t.mv_card_id IS NULL THEN ROW_JOURNAL ELSE ROW_CARD_PAYMENT END AS g_row_type,
           t.mv_date AS g_date,
           t.mv_card_id AS g_card_id,
           CASE WHEN t.mv_card_id IS NULL THEN MIN(t.mv_description) ELSE MIN(la.name) END AS g_description,
           SUM(t.mv_deposit)::BIGINT AS g_deposit,
           SUM(t.mv_withdrawal)::BIGINT AS g_withdrawal,
           MIN(t.mv_journal_id) AS g_first_id,
           -- カードの行は元のお買い物の仕訳、それ以外はその仕訳
           ARRAY_AGG(COALESCE(t.mv_original_id, t.mv_journal_id)::BIGINT ORDER BY t.mv_journal_id) AS g_journal_ids
      FROM tagged t
      LEFT JOIN liability_accounts la ON la.id = t.mv_card_id
     GROUP BY t.mv_date, t.mv_card_id, CASE WHEN t.mv_card_id IS NULL THEN t.mv_journal_id END
  )
  -- 1 行目は繰越。続けて日付順（同じ日は仕訳の登録順）に、残高を積み上げる
  SELECT r.r_row_type, r.r_date, r.r_card_id, r.r_description, r.r_deposit, r.r_withdrawal, r.r_balance,
         r.r_journal_ids
    FROM (
      SELECT ROW_CARRIED_OVER AS r_row_type, from_date - 1 AS r_date, NULL::BIGINT AS r_card_id,
             '繰越'::TEXT AS r_description, 0::BIGINT AS r_deposit, 0::BIGINT AS r_withdrawal,
             v_carried_over AS r_balance, ARRAY[]::BIGINT[] AS r_journal_ids,
             0 AS r_order, 0::BIGINT AS r_first_id
      UNION ALL
      SELECT g.g_row_type, g.g_date, g.g_card_id, g.g_description, g.g_deposit, g.g_withdrawal,
             (v_carried_over + SUM(g.g_deposit - g.g_withdrawal) OVER (ORDER BY g.g_date, g.g_first_id))::BIGINT,
             g.g_journal_ids,
             1, g.g_first_id::BIGINT
        FROM grouped g
    ) r
   ORDER BY r.r_order, r.r_date, r.r_first_id;
END;
$$;


--
-- Name: get_last_date_of_month(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_last_date_of_month(y integer, m integer) RETURNS date
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_first_date_of_next_month DATE;
BEGIN
  v_first_date_of_next_month := (MAKE_DATE(y, m, 1) + INTERVAL '1 month')::DATE;

  RETURN v_first_date_of_next_month - 1;
END;
$$;


--
-- Name: get_monthly_expenses(integer, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_monthly_expenses(user_id integer, target_month date) RETURNS TABLE(account_id bigint, account_name text, amount bigint)
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_month_start DATE;
  ELEMENT_EXPENSES CONSTANT INT := 5;
BEGIN
  -- target_month は月内のどの日付でもよい
  v_month_start := DATE_TRUNC('month', target_month)::DATE;

  -- 仕訳日が当月の費用科目の借方を、科目ごとに合計する（金額の大きい順）
  RETURN QUERY
  SELECT ea.id::BIGINT, ea.name, SUM(d.amount)::BIGINT
    FROM debits d
    JOIN journals j ON j.id = d.journal_id
    JOIN expense_accounts ea ON ea.id = d.account_id
   WHERE d.element_type = ELEMENT_EXPENSES
     AND j.user_id = get_monthly_expenses.user_id
     AND j.journal_dt >= v_month_start
     AND j.journal_dt < (v_month_start + INTERVAL '1 month')::DATE
   GROUP BY ea.id, ea.name
   ORDER BY SUM(d.amount) DESC, ea.id;
END;
$$;


--
-- Name: get_next_business_day(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_next_business_day(p_date date) RETURNS date
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_date DATE := p_date;
  SUNDAY CONSTANT INT := 0;
  SATURDAY CONSTANT INT := 6;
BEGIN
  LOOP
    -- 土日なら翌日へ
    IF EXTRACT(DOW FROM v_date) IN (SUNDAY, SATURDAY) THEN
      v_date := v_date + 1;
      CONTINUE;
    END IF;

    -- 祝日・銀行休日なら翌日へ（holidays に未登録の期間は土日のみで判定される）
    IF EXISTS (SELECT 1 FROM holidays h WHERE h.holiday = v_date) THEN
      v_date := v_date + 1;
      CONTINUE;
    END IF;

    EXIT;
  END LOOP;

  RETURN v_date;
END;
$$;


--
-- Name: get_payment_date(integer, integer, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_payment_date(cutoff_day integer, payment_day integer, journal_date date) RETURNS date
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_first_date_of_month DATE;
  v_cutoff_date DATE;
  v_months_ahead INT;
  v_payment_month DATE;
  v_payment_date DATE;
BEGIN
  v_first_date_of_month := DATE_TRUNC('month', journal_date)::DATE;

  -- 30・31 日締めのように月に存在しない日は、その月の末日に丸める
  v_cutoff_date := LEAST(
    v_first_date_of_month + (cutoff_day - 1),
    get_last_date_of_month(
      EXTRACT(YEAR FROM journal_date)::INT,
      EXTRACT(MONTH FROM journal_date)::INT
    )
  );

  -- 締日が支払日より前なら当月払い・翌月払い、締日が支払日以降なら翌月払い・翌々月払い
  IF cutoff_day < payment_day THEN
    v_months_ahead := CASE WHEN journal_date <= v_cutoff_date THEN 0 ELSE 1 END;
  ELSE
    v_months_ahead := CASE WHEN journal_date <= v_cutoff_date THEN 1 ELSE 2 END;
  END IF;

  v_payment_month := (v_first_date_of_month + (v_months_ahead * INTERVAL '1 month'))::DATE;

  -- 支払日も月に存在しない日（2 月 30 日など）は末日に丸める
  v_payment_date := LEAST(
    v_payment_month + (payment_day - 1),
    get_last_date_of_month(
      EXTRACT(YEAR FROM v_payment_month)::INT,
      EXTRACT(MONTH FROM v_payment_month)::INT
    )
  );

  RETURN get_next_business_day(v_payment_date);
END;
$$;


--
-- Name: insert_journal_entry(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.insert_journal_entry(journal_data jsonb) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  new_journal_id INT;
  v_journal_date DATE;
  v_store_name TEXT;
  v_user_id INT;
  v_sum_debit INT := 0;
  v_sum_credit INT := 0;
  v_entry RECORD;
  v_available BOOLEAN;
  ELEMENT_ASSETS CONSTANT INT := 1;
  ELEMENT_LIABILITIES CONSTANT INT := 2;
  ELEMENT_EQUITY CONSTANT INT := 3;
  ELEMENT_EXPENSES CONSTANT INT := 5;
BEGIN
  -- 1. 借方の合計金額を計算
  SELECT COALESCE(SUM(amount), 0) INTO v_sum_debit
  FROM jsonb_to_recordset(journal_data->'debits') AS x(amount INT);

  -- 2. 貸方の合計金額を計算
  SELECT COALESCE(SUM(amount), 0) INTO v_sum_credit
  FROM jsonb_to_recordset(journal_data->'credits') AS x(amount INT);

  -- 3. 貸借不一致のバリデーション（金額が合わなければエラーを投げる）
  IF v_sum_debit <> v_sum_credit THEN
    RAISE EXCEPTION 'unbalance debit and credit. debit: %, credit: %', v_sum_debit, v_sum_credit
      USING ERRCODE = 'P0001'; -- Check Violation のエラーコードを指定
  END IF;

  -- 金額が一致している場合のみ、以降のインサート処理が実行されます
  -- 4. 親情報の抽出
  v_journal_date := (journal_data->>'date')::DATE;
  v_store_name   := (journal_data->>'store_name')::TEXT;
  v_user_id      := (journal_data->>'user_id')::INT;

  -- 4.5 借方・貸方の科目が使えるか確認する
  -- 資産・負債科目は本人のもののみ。費用・資本科目は共通科目（user_id IS NULL）も使える。
  -- 他人の科目と存在しない科目は区別しない。収益科目はテーブルが無いため常に使えない
  FOR v_entry IN
    SELECT d.element_type, d.account_id
      FROM jsonb_to_recordset(journal_data->'debits') AS d(element_type INT, account_id INT)
    UNION ALL
    SELECT c.element_type, c.account_id
      FROM jsonb_to_recordset(journal_data->'credits') AS c(element_type INT, account_id INT)
  LOOP
    v_available := CASE v_entry.element_type
      WHEN ELEMENT_ASSETS THEN EXISTS (
        SELECT 1 FROM asset_accounts a
         WHERE a.id = v_entry.account_id AND a.user_id = v_user_id
      )
      WHEN ELEMENT_LIABILITIES THEN EXISTS (
        SELECT 1 FROM liability_accounts a
         WHERE a.id = v_entry.account_id AND a.user_id = v_user_id
      )
      WHEN ELEMENT_EQUITY THEN EXISTS (
        SELECT 1 FROM equity_accounts a
         WHERE a.id = v_entry.account_id AND (a.user_id IS NULL OR a.user_id = v_user_id)
      )
      WHEN ELEMENT_EXPENSES THEN EXISTS (
        SELECT 1 FROM expense_accounts a
         WHERE a.id = v_entry.account_id AND (a.user_id IS NULL OR a.user_id = v_user_id)
      )
      ELSE FALSE
    END;

    IF NOT v_available THEN
      RAISE EXCEPTION 'account not found: element_type=%, account_id=%', v_entry.element_type, v_entry.account_id;
    END IF;
  END LOOP;

  -- 5. 親仕訳データを作成
  INSERT INTO journals (
    journal_dt, store_name, user_id
  ) VALUES (
    v_journal_date,
    v_store_name,
    v_user_id
  )
  RETURNING id INTO new_journal_id;

  -- 6. 借方（debits）のインサート
  INSERT INTO debits (
    journal_id, element_type, account_id, item_name, amount, user_id
  )
  SELECT
    new_journal_id,
    element_type,
    account_id,
    item_name,
    amount,
    v_user_id
  FROM jsonb_to_recordset(journal_data->'debits')
    AS debits(
         element_type INT,
         account_id INT,
         item_name TEXT,
         amount INT
       );

  -- 7. 貸方（credits）のインサート
  INSERT INTO credits (
    journal_id, element_type, payment_method_type, account_id, amount, user_id
  )
  SELECT
    new_journal_id,
    element_type,
    payment_method_type,
    account_id,
    amount,
    v_user_id
  FROM jsonb_to_recordset(journal_data->'credits')
    AS credits(
         element_type INT,
         payment_method_type INT,
         account_id INT,
         amount INT
       );

  RETURN new_journal_id;
END;
$$;


--
-- Name: replace_journal_entry(integer, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.replace_journal_entry(journal_id integer, journal_data jsonb) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_user_id INT;
  v_new_journal_id INT;
  v_carry_payment_date DATE;
  v_carry_card_id INT;
  ELEMENT_EXPENSES CONSTANT INT := 5;
  ELEMENT_LIABILITIES CONSTANT INT := 2;
  PAYMENT_METHOD_CREDIT_CARD CONSTANT INT := 3;
  DIRECT_DEBIT_PAYMENT_DATE_SETTING CONSTANT TEXT := 'app.direct_debit_payment_date';
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

  -- 引き落とし日を手で変えていたら、その日とカードを覚えておく。
  -- カード払いが 1 つだけの仕訳に限る（複数あると、どの引き落としの日付か決められない）
  SELECT dj.journal_dt, dd.account_id
    INTO v_carry_payment_date, v_carry_card_id
    FROM direct_debit_journals ddj
    JOIN journals dj ON dj.id = ddj.direct_debit_id
    JOIN debits dd ON dd.journal_id = dj.id
   WHERE ddj.original_id = replace_journal_entry.journal_id
     AND ddj.payment_date_overridden
     AND (
       SELECT COUNT(*)
         FROM direct_debit_journals other
        WHERE other.original_id = replace_journal_entry.journal_id
     ) = 1
  ;

  -- 修正後も同じカード 1 枚での支払いで、買った日が引き落とし日より後にならないときだけ引き継ぐ。
  -- それ以外は、締め日・支払日からの自動の計算に戻す
  IF v_carry_payment_date IS NOT NULL AND NOT (
    (journal_data->>'date')::DATE <= v_carry_payment_date
    AND (
      SELECT COUNT(*) = 1 AND BOOL_AND(x.account_id = v_carry_card_id)
        FROM jsonb_to_recordset(journal_data->'credits')
          AS x(element_type INT, payment_method_type INT, account_id INT)
       WHERE x.element_type = ELEMENT_LIABILITIES
         AND x.payment_method_type = PAYMENT_METHOD_CREDIT_CARD
    )
  ) THEN
    v_carry_payment_date := NULL;
  END IF;

  -- 元の仕訳（と引き落とし仕訳）を消して、登録と同じ確認をしながら作り直す。
  -- どちらかで失敗すると、関数全体が取り消されて元の仕訳が残る
  PERFORM delete_journal(replace_journal_entry.journal_id, v_user_id);

  IF v_carry_payment_date IS NOT NULL THEN
    -- credits_after_insert トリガーに、引き落とし日として使わせる
    PERFORM set_config(DIRECT_DEBIT_PAYMENT_DATE_SETTING, v_carry_payment_date::TEXT, TRUE);
  END IF;

  v_new_journal_id := insert_journal_entry(journal_data);

  IF v_carry_payment_date IS NOT NULL THEN
    -- 同じトランザクションの後続の仕訳に影響しないよう、指定を消す
    PERFORM set_config(DIRECT_DEBIT_PAYMENT_DATE_SETTING, '', TRUE);

    -- 引き継いだ日も手で変えた日なので、次に修正したときも引き継ぐ
    UPDATE direct_debit_journals ddj
       SET payment_date_overridden = TRUE
     WHERE ddj.original_id = v_new_journal_id
    ;
  END IF;

  RETURN v_new_journal_id;
END;
$$;


--
-- Name: update_direct_debit_date(integer, date, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_direct_debit_date(journal_id integer, payment_date date, user_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_original_date DATE;
BEGIN
  -- 他ユーザーの仕訳と存在しない仕訳は区別しない。
  -- 同時に修正・削除されないよう、行をロックする
  PERFORM 1
     FROM journals j
    WHERE j.id = update_direct_debit_date.journal_id
      AND j.user_id = update_direct_debit_date.user_id
      FOR UPDATE
  ;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'journal not found: %', journal_id;
  END IF;

  -- 日付だけを変えられるのは、カード払いから自動で作られた引き落とし仕訳だけ
  SELECT oj.journal_dt
    INTO v_original_date
    FROM direct_debit_journals ddj
    JOIN journals oj ON oj.id = ddj.original_id
   WHERE ddj.direct_debit_id = update_direct_debit_date.journal_id
  ;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'journal is not a direct debit journal: %', journal_id;
  END IF;

  -- 買う前（開始負債なら開始日より前）に引き落とされることはない。
  -- それ以外は明細の日付をそのまま使い、営業日にはずらさない
  IF payment_date < v_original_date THEN
    RAISE EXCEPTION 'payment date must not be before journal date: payment_date=%, journal_date=%', payment_date, v_original_date;
  END IF;

  UPDATE journals j
     SET journal_dt = update_direct_debit_date.payment_date
   WHERE j.id = update_direct_debit_date.journal_id
  ;

  -- 元のお買い物を修正したときに、この日付を引き継げるよう記録する
  UPDATE direct_debit_journals ddj
     SET payment_date_overridden = TRUE
   WHERE ddj.direct_debit_id = update_direct_debit_date.journal_id
  ;

  RETURN journal_id;
END;
$$;


--
-- Name: update_updated_at_with_current_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at_with_current_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: asset_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.asset_accounts (
    id bigint NOT NULL,
    asset_type integer NOT NULL,
    name text NOT NULL,
    user_id bigint,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT asset_account_asset_type CHECK ((asset_type = ANY (ARRAY[1, 2, 3])))
);


--
-- Name: asset_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.asset_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: asset_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.asset_accounts_id_seq OWNED BY public.asset_accounts.id;


--
-- Name: credit_cards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.credit_cards (
    id bigint NOT NULL,
    liability_account_id bigint,
    bank_account_id bigint,
    cutoff_day integer NOT NULL,
    payment_day integer NOT NULL,
    user_id bigint,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT credit_cards_cutoff_day_check CHECK (((cutoff_day >= 1) AND (cutoff_day <= 31))),
    CONSTRAINT credit_cards_payment_day_check CHECK (((payment_day >= 1) AND (payment_day <= 31)))
);


--
-- Name: credit_cards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.credit_cards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: credit_cards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.credit_cards_id_seq OWNED BY public.credit_cards.id;


--
-- Name: credit_cards_updated_at_triggers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.credit_cards_updated_at_triggers (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: credit_cards_updated_at_triggers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.credit_cards_updated_at_triggers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: credit_cards_updated_at_triggers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.credit_cards_updated_at_triggers_id_seq OWNED BY public.credit_cards_updated_at_triggers.id;


--
-- Name: credits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.credits (
    id bigint NOT NULL,
    journal_id bigint,
    element_type integer NOT NULL,
    payment_method_type integer NOT NULL,
    account_id integer NOT NULL,
    amount integer NOT NULL,
    user_id bigint,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT credit_element_type CHECK ((element_type = ANY (ARRAY[1, 2, 3, 4, 5]))),
    CONSTRAINT credit_payment_method_type CHECK ((((element_type = 1) AND (payment_method_type = ANY (ARRAY[1, 2, 3]))) OR ((element_type = 2) AND (payment_method_type = ANY (ARRAY[1, 2, 3]))) OR ((element_type = ANY (ARRAY[3, 4, 5])) AND (payment_method_type = 0))))
);


--
-- Name: credits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.credits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: credits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.credits_id_seq OWNED BY public.credits.id;


--
-- Name: debits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.debits (
    id bigint NOT NULL,
    journal_id bigint,
    element_type integer NOT NULL,
    account_id integer NOT NULL,
    item_name text,
    amount integer NOT NULL,
    user_id bigint,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT debit_element_type CHECK ((element_type = ANY (ARRAY[1, 2, 3, 4, 5])))
);


--
-- Name: debits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.debits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: debits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.debits_id_seq OWNED BY public.debits.id;


--
-- Name: direct_debit_journals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.direct_debit_journals (
    id bigint NOT NULL,
    original_id bigint,
    direct_debit_id bigint,
    user_id bigint,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    payment_date_overridden boolean DEFAULT false NOT NULL
);


--
-- Name: direct_debit_journals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.direct_debit_journals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: direct_debit_journals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.direct_debit_journals_id_seq OWNED BY public.direct_debit_journals.id;


--
-- Name: direct_debit_journals_updated_at_triggers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.direct_debit_journals_updated_at_triggers (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: direct_debit_journals_updated_at_triggers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.direct_debit_journals_updated_at_triggers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: direct_debit_journals_updated_at_triggers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.direct_debit_journals_updated_at_triggers_id_seq OWNED BY public.direct_debit_journals_updated_at_triggers.id;


--
-- Name: equity_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.equity_accounts (
    id bigint NOT NULL,
    name text NOT NULL,
    user_id bigint,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: equity_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.equity_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: equity_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.equity_accounts_id_seq OWNED BY public.equity_accounts.id;


--
-- Name: expense_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.expense_accounts (
    id bigint NOT NULL,
    parent_id bigint,
    name text NOT NULL,
    user_id bigint,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: expense_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.expense_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: expense_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.expense_accounts_id_seq OWNED BY public.expense_accounts.id;


--
-- Name: holiday_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.holiday_types (
    id bigint NOT NULL,
    name text NOT NULL,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: holiday_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.holiday_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: holiday_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.holiday_types_id_seq OWNED BY public.holiday_types.id;


--
-- Name: holidays; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.holidays (
    id bigint NOT NULL,
    holiday date NOT NULL,
    holiday_type_id bigint,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: holidays_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.holidays_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: holidays_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.holidays_id_seq OWNED BY public.holidays.id;


--
-- Name: journals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.journals (
    id bigint NOT NULL,
    journal_dt date NOT NULL,
    store_id bigint,
    store_name text,
    user_id bigint,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: journals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.journals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: journals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.journals_id_seq OWNED BY public.journals.id;


--
-- Name: liability_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.liability_accounts (
    id bigint NOT NULL,
    liability_type integer NOT NULL,
    name text NOT NULL,
    user_id bigint,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT liability_account_liability_type CHECK ((liability_type = ANY (ARRAY[1, 2, 3])))
);


--
-- Name: liability_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.liability_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: liability_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.liability_accounts_id_seq OWNED BY public.liability_accounts.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: stores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stores (
    id bigint NOT NULL,
    name text,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: stores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.stores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.stores_id_seq OWNED BY public.stores.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    name text,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    password_digest text
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: asset_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset_accounts ALTER COLUMN id SET DEFAULT nextval('public.asset_accounts_id_seq'::regclass);


--
-- Name: credit_cards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_cards ALTER COLUMN id SET DEFAULT nextval('public.credit_cards_id_seq'::regclass);


--
-- Name: credit_cards_updated_at_triggers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_cards_updated_at_triggers ALTER COLUMN id SET DEFAULT nextval('public.credit_cards_updated_at_triggers_id_seq'::regclass);


--
-- Name: credits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credits ALTER COLUMN id SET DEFAULT nextval('public.credits_id_seq'::regclass);


--
-- Name: debits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.debits ALTER COLUMN id SET DEFAULT nextval('public.debits_id_seq'::regclass);


--
-- Name: direct_debit_journals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direct_debit_journals ALTER COLUMN id SET DEFAULT nextval('public.direct_debit_journals_id_seq'::regclass);


--
-- Name: direct_debit_journals_updated_at_triggers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direct_debit_journals_updated_at_triggers ALTER COLUMN id SET DEFAULT nextval('public.direct_debit_journals_updated_at_triggers_id_seq'::regclass);


--
-- Name: equity_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.equity_accounts ALTER COLUMN id SET DEFAULT nextval('public.equity_accounts_id_seq'::regclass);


--
-- Name: expense_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_accounts ALTER COLUMN id SET DEFAULT nextval('public.expense_accounts_id_seq'::regclass);


--
-- Name: holiday_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.holiday_types ALTER COLUMN id SET DEFAULT nextval('public.holiday_types_id_seq'::regclass);


--
-- Name: holidays id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.holidays ALTER COLUMN id SET DEFAULT nextval('public.holidays_id_seq'::regclass);


--
-- Name: journals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journals ALTER COLUMN id SET DEFAULT nextval('public.journals_id_seq'::regclass);


--
-- Name: liability_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.liability_accounts ALTER COLUMN id SET DEFAULT nextval('public.liability_accounts_id_seq'::regclass);


--
-- Name: stores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores ALTER COLUMN id SET DEFAULT nextval('public.stores_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: asset_accounts asset_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset_accounts
    ADD CONSTRAINT asset_accounts_pkey PRIMARY KEY (id);


--
-- Name: credit_cards credit_cards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_cards
    ADD CONSTRAINT credit_cards_pkey PRIMARY KEY (id);


--
-- Name: credit_cards_updated_at_triggers credit_cards_updated_at_triggers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_cards_updated_at_triggers
    ADD CONSTRAINT credit_cards_updated_at_triggers_pkey PRIMARY KEY (id);


--
-- Name: credits credits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credits
    ADD CONSTRAINT credits_pkey PRIMARY KEY (id);


--
-- Name: debits debits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.debits
    ADD CONSTRAINT debits_pkey PRIMARY KEY (id);


--
-- Name: direct_debit_journals direct_debit_journals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direct_debit_journals
    ADD CONSTRAINT direct_debit_journals_pkey PRIMARY KEY (id);


--
-- Name: direct_debit_journals_updated_at_triggers direct_debit_journals_updated_at_triggers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direct_debit_journals_updated_at_triggers
    ADD CONSTRAINT direct_debit_journals_updated_at_triggers_pkey PRIMARY KEY (id);


--
-- Name: equity_accounts equity_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.equity_accounts
    ADD CONSTRAINT equity_accounts_pkey PRIMARY KEY (id);


--
-- Name: expense_accounts expense_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_accounts
    ADD CONSTRAINT expense_accounts_pkey PRIMARY KEY (id);


--
-- Name: holiday_types holiday_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.holiday_types
    ADD CONSTRAINT holiday_types_pkey PRIMARY KEY (id);


--
-- Name: holidays holidays_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.holidays
    ADD CONSTRAINT holidays_pkey PRIMARY KEY (id);


--
-- Name: journals journals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journals
    ADD CONSTRAINT journals_pkey PRIMARY KEY (id);


--
-- Name: liability_accounts liability_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.liability_accounts
    ADD CONSTRAINT liability_accounts_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: stores stores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores
    ADD CONSTRAINT stores_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_asset_accounts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_asset_accounts_on_user_id ON public.asset_accounts USING btree (user_id);


--
-- Name: index_credit_cards_on_bank_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_cards_on_bank_account_id ON public.credit_cards USING btree (bank_account_id);


--
-- Name: index_credit_cards_on_liability_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_cards_on_liability_account_id ON public.credit_cards USING btree (liability_account_id);


--
-- Name: index_credit_cards_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credit_cards_on_user_id ON public.credit_cards USING btree (user_id);


--
-- Name: index_credits_on_journal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credits_on_journal_id ON public.credits USING btree (journal_id);


--
-- Name: index_credits_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_credits_on_user_id ON public.credits USING btree (user_id);


--
-- Name: index_debits_on_journal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_debits_on_journal_id ON public.debits USING btree (journal_id);


--
-- Name: index_debits_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_debits_on_user_id ON public.debits USING btree (user_id);


--
-- Name: index_direct_debit_journals_on_direct_debit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_direct_debit_journals_on_direct_debit_id ON public.direct_debit_journals USING btree (direct_debit_id);


--
-- Name: index_direct_debit_journals_on_original_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_direct_debit_journals_on_original_id ON public.direct_debit_journals USING btree (original_id);


--
-- Name: index_direct_debit_journals_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_direct_debit_journals_on_user_id ON public.direct_debit_journals USING btree (user_id);


--
-- Name: index_equity_accounts_on_common_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_equity_accounts_on_common_name ON public.equity_accounts USING btree (name) WHERE (user_id IS NULL);


--
-- Name: index_equity_accounts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_equity_accounts_on_user_id ON public.equity_accounts USING btree (user_id);


--
-- Name: index_expense_accounts_on_common_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_expense_accounts_on_common_name ON public.expense_accounts USING btree (COALESCE(parent_id, (0)::bigint), name) WHERE (user_id IS NULL);


--
-- Name: index_expense_accounts_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_expense_accounts_on_parent_id ON public.expense_accounts USING btree (parent_id);


--
-- Name: index_expense_accounts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_expense_accounts_on_user_id ON public.expense_accounts USING btree (user_id);


--
-- Name: index_holidays_on_holiday; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_holidays_on_holiday ON public.holidays USING btree (holiday);


--
-- Name: index_holidays_on_holiday_type_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_holidays_on_holiday_type_id ON public.holidays USING btree (holiday_type_id);


--
-- Name: index_journals_on_store_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_journals_on_store_id ON public.journals USING btree (store_id);


--
-- Name: index_journals_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_journals_on_user_id ON public.journals USING btree (user_id);


--
-- Name: index_liability_accounts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_liability_accounts_on_user_id ON public.liability_accounts USING btree (user_id);


--
-- Name: index_users_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_name ON public.users USING btree (name);


--
-- Name: credits credits_after_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER credits_after_insert AFTER INSERT ON public.credits FOR EACH ROW EXECUTE FUNCTION public.credits_after_insert_fn();


--
-- Name: asset_accounts trigger_update_updated_at_of_asset_accounts; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_asset_accounts BEFORE UPDATE ON public.asset_accounts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: credits trigger_update_updated_at_of_credits; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_credits BEFORE UPDATE ON public.credits FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: debits trigger_update_updated_at_of_debits; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_debits BEFORE UPDATE ON public.debits FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: equity_accounts trigger_update_updated_at_of_equity_accounts; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_equity_accounts BEFORE UPDATE ON public.equity_accounts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: expense_accounts trigger_update_updated_at_of_expense_accounts; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_expense_accounts BEFORE UPDATE ON public.expense_accounts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: holiday_types trigger_update_updated_at_of_holiday_types; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_holiday_types BEFORE UPDATE ON public.holiday_types FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: holidays trigger_update_updated_at_of_holidays; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_holidays BEFORE UPDATE ON public.holidays FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: journals trigger_update_updated_at_of_journals; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_journals BEFORE UPDATE ON public.journals FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: liability_accounts trigger_update_updated_at_of_liability_accounts; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_liability_accounts BEFORE UPDATE ON public.liability_accounts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: stores trigger_update_updated_at_of_stores; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_stores BEFORE UPDATE ON public.stores FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: users trigger_update_updated_at_of_users; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_updated_at_of_users BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_with_current_timestamp();


--
-- Name: credit_cards fk_rails_069bf994f3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_cards
    ADD CONSTRAINT fk_rails_069bf994f3 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: liability_accounts fk_rails_0999c965ca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.liability_accounts
    ADD CONSTRAINT fk_rails_0999c965ca FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: journals fk_rails_1f2015adde; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journals
    ADD CONSTRAINT fk_rails_1f2015adde FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: direct_debit_journals fk_rails_29f8d7e878; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direct_debit_journals
    ADD CONSTRAINT fk_rails_29f8d7e878 FOREIGN KEY (direct_debit_id) REFERENCES public.journals(id);


--
-- Name: debits fk_rails_410320ab9b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.debits
    ADD CONSTRAINT fk_rails_410320ab9b FOREIGN KEY (journal_id) REFERENCES public.journals(id);


--
-- Name: journals fk_rails_4cdc69e25e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journals
    ADD CONSTRAINT fk_rails_4cdc69e25e FOREIGN KEY (store_id) REFERENCES public.stores(id);


--
-- Name: credit_cards fk_rails_6ee196f565; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_cards
    ADD CONSTRAINT fk_rails_6ee196f565 FOREIGN KEY (liability_account_id) REFERENCES public.liability_accounts(id);


--
-- Name: equity_accounts fk_rails_7ac996d2ab; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.equity_accounts
    ADD CONSTRAINT fk_rails_7ac996d2ab FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: credits fk_rails_9001739776; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credits
    ADD CONSTRAINT fk_rails_9001739776 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: direct_debit_journals fk_rails_b0186ae2fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direct_debit_journals
    ADD CONSTRAINT fk_rails_b0186ae2fd FOREIGN KEY (original_id) REFERENCES public.journals(id);


--
-- Name: credits fk_rails_b19f08971f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credits
    ADD CONSTRAINT fk_rails_b19f08971f FOREIGN KEY (journal_id) REFERENCES public.journals(id);


--
-- Name: expense_accounts fk_rails_b22d405b10; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_accounts
    ADD CONSTRAINT fk_rails_b22d405b10 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: holidays fk_rails_c617b5318d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.holidays
    ADD CONSTRAINT fk_rails_c617b5318d FOREIGN KEY (holiday_type_id) REFERENCES public.holiday_types(id);


--
-- Name: expense_accounts fk_rails_c6921d9c71; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_accounts
    ADD CONSTRAINT fk_rails_c6921d9c71 FOREIGN KEY (parent_id) REFERENCES public.expense_accounts(id);


--
-- Name: credit_cards fk_rails_ccaff89dd6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_cards
    ADD CONSTRAINT fk_rails_ccaff89dd6 FOREIGN KEY (bank_account_id) REFERENCES public.asset_accounts(id);


--
-- Name: asset_accounts fk_rails_d5e7f3287d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset_accounts
    ADD CONSTRAINT fk_rails_d5e7f3287d FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: debits fk_rails_e1ba88eebe; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.debits
    ADD CONSTRAINT fk_rails_e1ba88eebe FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: direct_debit_journals fk_rails_f395144e79; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direct_debit_journals
    ADD CONSTRAINT fk_rails_f395144e79 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261120150000'),
('20261120142000'),
('20261120141000'),
('20261120140000'),
('20261120130000'),
('20261120120000'),
('20261029065000'),
('20261029064000'),
('20261029063000'),
('20261029062000'),
('20261029061000'),
('20261029060000'),
('20261028120000'),
('20261028090000'),
('20261027120000'),
('20260708223810'),
('20251226065757'),
('20251220053020'),
('20251220025518'),
('20251220025453'),
('20251220025037'),
('20251220025023'),
('20251220024035'),
('20251220024020'),
('20251220021750'),
('20251220021736'),
('20251220015651'),
('20251220015554'),
('20251220014440'),
('20251220014419'),
('20251220013210'),
('20251220013146'),
('20251220011411'),
('20251220011323'),
('20251219051931'),
('20251219051909'),
('20251219045735'),
('20251219045705'),
('20251219045644'),
('20251219045628'),
('20251219044754'),
('20251219044736'),
('20251219044709'),
('20251219044647'),
('20251219041458');

