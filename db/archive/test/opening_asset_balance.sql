SELECT generate_opening_asset_balance_journal(
  '2025-12-13',
  1,
  (SELECT id FROM asset_accounts WHERE name = '現金'),
  500000,
  (SELECT id FROM users WHERE name = 'masa')
);

SELECT generate_opening_asset_balance_journal(
  '2025-12-15',
  2,
  (SELECT id FROM asset_accounts WHERE name = '三菱UFJ銀行 用賀出張所'),
  40000,
  (SELECT id FROM users WHERE name = 'masa')
);

