SELECT generate_make_a_cash_deposit_journal(
  '2025-12-09',
  (SELECT id FROM asset_accounts WHERE name = '三菱UFJ銀行 用賀出張所'),
  45000,
  (SELECT id FROM users WHERE name = 'masa')
);
