INSERT INTO journals (
  journal_dt, store_id, store_name, user_id
) VALUES (
  '2025-11-23',
  (SELECT id FROM stores WHERE name = 'まいばすけっと'),
  'まいばすけっと 001',
  (SELECT id FROM users WHERE name = 'masa')
);

INSERT INTO debits (
  journal_id, element_type, account_id, item_name, amount, user_id
) VALUES (
  (SELECT id FROM journals WHERE store_name = 'まいばすけっと 001'),
  5,
  (SELECT id FROM expense_accounts WHERE name = '食費'),
  'もやし、しめじ等',
  417,
  (SELECT id FROM users WHERE name = 'masa')
);

INSERT INTO credits (
  journal_id, element_type, payment_method_type, account_id, amount, user_id
) VALUES (
  (SELECT id FROM journals WHERE store_name = 'まいばすけっと 001'),
  1,
  1,
  (SELECT id FROM asset_accounts WHERE name = '現金'),
  417,
  (SELECT id FROM users WHERE name = 'masa')
);
