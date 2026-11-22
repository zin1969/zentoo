CREATE OR REPLACE FUNCTION get_pending_recurring_dates(
  user_id INT,
  to_date DATE
)
RETURNS TABLE (
  recurring_entry_id BIGINT,
  scheduled_date DATE
)
LANGUAGE plpgsql AS $$
DECLARE
BEGIN
  -- 開始日から to_date までの予定日のうち、登録も飛ばしもしていない回。
  -- 取り残し（先月以前の未登録の回）も出すため、開始日から数える
  RETURN QUERY
  SELECT re.id, d.d_date
    FROM recurring_entries re
   CROSS JOIN LATERAL get_recurring_dates(
     re.interval_unit, re.interval_count, re.day_of_month, re.weekday,
     re.start_date, re.end_date, re.start_date, get_pending_recurring_dates.to_date
   ) AS d(d_date)
   WHERE re.user_id = get_pending_recurring_dates.user_id
     AND NOT EXISTS (
       SELECT 1
         FROM recurring_entry_occurrences o
        WHERE o.recurring_entry_id = re.id
          AND o.scheduled_date = d.d_date
     )
   ORDER BY d.d_date, re.id;
END;
$$;
