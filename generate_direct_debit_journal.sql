CREATE OR REPLACE FUNCTION generate_direct_journal()
RETURNS TRIGGER AS $$
DECLARE
  record_exists BOOLEAN;
  OUT new_id INT;
BEGIN
  -- カード支払い以外は処理をしない
  -- アーリーリターン（早期離脱）
  IF NOT (NEW.type = 2 AND NEW.payment_method_type = 3) THEN
    RETURN NEW;
  END IF;

  -- 口座振替用 journal レコードの存在を確認
  -- 存在しなければ、レコードを生成
  SELECT EXISTS (
    SELECT 1
      FROM direct_debit_journals
     WHERE original_id = NEW.journal_id
  ) INTO record_exists;

  IF NOT record_exists THEN
    INSERT INTO journals (
    ) VALUES (
    )
    RETURNING id INTO new_id;
  END IF;
END;
$$ LANGUAGE plpgsql;
