CREATE OR REPLACE FUNCTION get_next_business_day(
  p_date DATE
)
RETURNS DATE
LANGUAGE plpgsql AS $$
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
