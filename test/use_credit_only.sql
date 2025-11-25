INSERT INTO journals (
  journal_dt, store_id, store_name, user_id
) VALUES (
  '2025-11-25',
  (SELECT id FROM stores WHERE name = 'Aquavit'),
  'Aquavit 001',
  (SELECT id FROM users WHERE name = 'masa')
);

INSERT INTO debits (
  journal_id, type, account_id, item_name, amount, user_id
) VALUES (
  (SELECT id FROM journals WHERE store_name = 'Aquavit 001'),
  5,
  (SELECT id FROM expense_accounts WHERE name = '外食費'),
  'バー',
  3300,
  (SELECT id FROM users WHERE name = 'masa')
);

INSERT INTO credits (
  journal_id, type, payment_method_type, account_id, amount, user_id
) VALUES (
  (SELECT id FROM journals WHERE store_name = 'Aquavit 001'),
  2,
  3,
  (SELECT id FROM liability_accounts WHERE name = 'JAL'),
  3300,
  (SELECT id FROM users WHERE name = 'masa')
);
