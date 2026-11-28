CREATE OR REPLACE FUNCTION get_budget_report(
  user_id INT,
  as_of_date DATE
)
RETURNS TABLE (
  budget_id BIGINT,
  period_start DATE,
  period_end DATE,
  budget_amount BIGINT,
  used_amount BIGINT
)
LANGUAGE plpgsql AS $$
DECLARE
  ELEMENT_EXPENSES CONSTANT INT := 5;
  TARGET_EXPENSE_ACCOUNT CONSTANT INT := 1;
  TARGET_TAG CONSTANT INT := 2;
  PERIOD_WEEK CONSTANT INT := 1;
  PERIOD_MONTH CONSTANT INT := 2;
BEGIN
  -- 予算ごとに、指定日を含む期間（週は月曜〜日曜、月、年は 1 月〜12 月）の予算額と使った額を返す。
  -- 使った額は、期間の中の日付（買った日）の費用の明細の合計。立替金の明細は費用ではないので入らない
  RETURN QUERY
  WITH periods AS (
    SELECT b.id AS p_budget_id,
           b.target_type AS p_target_type,
           b.expense_account_id AS p_expense_account_id,
           b.tag_id AS p_tag_id,
           b.amount AS p_amount,
           b.monthly_amounts AS p_monthly_amounts,
           CASE b.period_type
             WHEN PERIOD_WEEK THEN as_of_date - (EXTRACT(ISODOW FROM as_of_date)::INT - 1)
             WHEN PERIOD_MONTH THEN DATE_TRUNC('month', as_of_date)::DATE
             ELSE DATE_TRUNC('year', as_of_date)::DATE
           END AS p_start,
           b.period_type AS p_period_type
      FROM budgets b
     WHERE b.user_id = get_budget_report.user_id
  ), ranges AS (
    SELECT p.*,
           CASE p.p_period_type
             WHEN PERIOD_WEEK THEN p.p_start + 6
             WHEN PERIOD_MONTH THEN (p.p_start + INTERVAL '1 month')::DATE - 1
             ELSE (p.p_start + INTERVAL '1 year')::DATE - 1
           END AS p_end
      FROM periods p
  )
  SELECT r.p_budget_id::BIGINT,
         r.p_start,
         r.p_end,
         -- 月ごとに決めた額があれば、その月の額
         COALESCE(r.p_monthly_amounts[EXTRACT(MONTH FROM r.p_start)::INT], r.p_amount)::BIGINT,
         COALESCE((
           SELECT SUM(d.amount)
             FROM debits d
             JOIN journals j ON j.id = d.journal_id
            WHERE j.user_id = get_budget_report.user_id
              AND j.journal_dt BETWEEN r.p_start AND r.p_end
              AND d.element_type = ELEMENT_EXPENSES
              AND (
                -- 費用科目: その科目と子科目。除くタグの付いた明細は外す
                (
                  r.p_target_type = TARGET_EXPENSE_ACCOUNT
                  AND (
                    d.account_id = r.p_expense_account_id
                    OR d.account_id IN (
                      SELECT ea.id FROM expense_accounts ea WHERE ea.parent_id = r.p_expense_account_id
                    )
                  )
                  AND NOT EXISTS (
                    SELECT 1
                      FROM debit_tags dt
                      JOIN budget_excluded_tags bet ON bet.tag_id = dt.tag_id
                     WHERE dt.debit_id = d.id
                       AND bet.budget_id = r.p_budget_id
                  )
                )
                -- タグ: そのタグが付いた明細
                OR (
                  r.p_target_type = TARGET_TAG
                  AND EXISTS (
                    SELECT 1
                      FROM debit_tags dt
                     WHERE dt.debit_id = d.id
                       AND dt.tag_id = r.p_tag_id
                  )
                )
              )
         ), 0)::BIGINT
    FROM ranges r
   ORDER BY r.p_period_type, r.p_budget_id;
END;
$$;
