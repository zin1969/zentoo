CREATE OR REPLACE FUNCTION get_next_business_day(p_date date)
RETURNS date AS $$
DECLARE
    d date := p_date;
BEGIN
    LOOP
        -- 土日なら翌日へ
        IF EXTRACT(DOW FROM d) IN (0,6) THEN
            d := d + INTERVAL '1 day';
            CONTINUE;
        END IF;

        -- 祝日なら翌日へ
        IF EXISTS (SELECT 1 FROM holidays WHERE holiday = d) THEN
            d := d + INTERVAL '1 day';
            CONTINUE;
        END IF;

        -- 上記に該当しなければ営業日
        EXIT;
    END LOOP;

    RETURN d;
END;
$$ LANGUAGE plpgsql;
