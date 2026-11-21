CREATE OR REPLACE FUNCTION get_bank_account_ledger(
  user_id INT,
  asset_account_id INT,
  from_date DATE,
  to_date DATE
)
RETURNS TABLE (
  row_type TEXT,
  entry_date DATE,
  card_account_id BIGINT,
  description TEXT,
  deposit BIGINT,
  withdrawal BIGINT,
  balance BIGINT,
  journal_ids BIGINT[]
)
LANGUAGE plpgsql AS $$
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
