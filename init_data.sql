INSERT INTO holiday_types (
  id, name
) VALUES (
  1, '元日'
), (
  2, '成人の日'
), (
  3, '建国記念の日'
), (
  4, '天皇誕生日'
), (
  5, '春分の日'
), (
  6, '昭和の日'
), (
  7, '憲法記念日'
), (
  8, 'みどりの日'
), (
  9, 'こどもの日'
), (
  10, '海の日'
), (
  11, '山の日'
), (
  12, '敬老の日'
), (
  13, '秋分の日'
), (
  14, 'スポーツの日'
), (
  15, '文化の日'
), (
  16, '勤労感謝の日'
), (
  17, '休日'
), (
  21, '銀行休日'
);

INSERT INTO holidays (
  holiday, holiday_type_id
) VALUES (
  '2025-01-01', 1
), (
  '2025-01-02', 21
), (
  '2025-01-03', 21
), (
  '2025-01-13', 2
), (
  '2025-02-11', 3
), (
  '2025-02-23', 4
), (
  '2025-02-24', 17
), (
  '2025-03-20', 5
), (
  '2025-04-29', 6
), (
  '2025-05-03', 7
), (
  '2025-05-04', 8
), (
  '2025-05-05', 9
), (
  '2025-05-06', 17
), (
  '2025-07-21', 10
), (
  '2025-08-11', 11
), (
  '2025-09-15', 12
), (
  '2025-09-23', 13
), (
  '2025-10-13', 14
), (
  '2025-11-03', 15
), (
  '2025-11-23', 16
), (
  '2025-11-24', 17
), (
  '2025-12-31', 21
), (
  '2026-01-01', 1
), (
  '2026-01-02', 21
), (
  '2026-01-03', 21
), (
  '2026-01-12', 2
), (
  '2026-02-11', 3
), (
  '2026-02-23', 4
), (
  '2026-03-20', 5
), (
  '2026-04-29', 6
), (
  '2026-05-03', 7
), (
  '2026-05-04', 8
), (
  '2026-05-05', 9
), (
  '2026-05-06', 17
), (
  '2026-07-20', 10
), (
  '2026-08-11', 11
), (
  '2026-09-21', 12
), (
  '2026-09-22', 17
), (
  '2026-09-23', 13
), (
  '2026-10-12', 14
), (
  '2026-11-03', 15
), (
  '2026-11-23', 16
), (
  '2026-12-31', 21
);

INSERT INTO users (
  name
) VALUES (
  'system'
), (
  'masa'
);

INSERT INTO stores (
  name
) VALUES (
  'Aquavit'
), (
  'まいばすけっと'
);

INSERT INTO expense_accounts (
  name, user_id
) VALUES (
  'root',
  (SELECT id FROM users WHERE name = 'masa')
);

INSERT INTO expense_accounts (
  parent_id, name, user_id
) VALUES (
  (SELECT id FROM expense_accounts WHERE name = 'root'),
  '食費',
  (SELECT id FROM users WHERE name = 'masa')
), (
  (SELECT id FROM expense_accounts WHERE name = 'root'),
  '娯楽費',
  (SELECT id FROM users WHERE name = 'masa')
), (
  (SELECT id FROM expense_accounts WHERE name = 'root'),
  '交通費',
  (SELECT id FROM users WHERE name = 'masa')
), (
  (SELECT id FROM expense_accounts WHERE name = 'root'),
  '教育費',
  (SELECT id FROM users WHERE name = 'masa')
);

INSERT INTO expense_accounts (
  parent_id, name, user_id
) VALUES (
  (SELECT id FROM expense_accounts WHERE name = '食費'),
  '外食費',
  (SELECT id FROM users WHERE name = 'masa')
), (
  (SELECT id FROM expense_accounts WHERE name = '娯楽費'),
  '映画',
  (SELECT id FROM users WHERE name = 'masa')
), (
  (SELECT id FROM expense_accounts WHERE name = '娯楽費'),
  '配信サービス',
  (SELECT id FROM users WHERE name = 'masa')
), (
  (SELECT id FROM expense_accounts WHERE name = '娯楽費'),
  '漫画',
  (SELECT id FROM users WHERE name = 'masa')
);

INSERT INTO liability_accounts (
  liability_type, name, user_id
) VALUES (
  3,
  'JAL',
  (SELECT id FROM users WHERE name = 'masa')
), (
  3,
  'enoteca',
  (SELECT id FROM users WHERE name = 'masa')
), (
  3,
  'tcard',
  (SELECT id FROM users WHERE name = 'masa')
), (
  3,
  'PayPay',
  (SELECT id FROM users WHERE name = 'masa')
);

INSERT INTO asset_accounts (
  asset_type, name, user_id
) VALUES (
  1,
  '現金',
  (SELECT id FROM users WHERE name = 'masa')
), (
  2,
  '三菱UFJ銀行 用賀出張所',
  (SELECT id FROM users WHERE name = 'masa')
), (
  2,
  'みずほ銀行 玉川支店',
  (SELECT id FROM users WHERE name = 'masa')
), (
  3,
  'Suica',
  (SELECT id FROM users WHERE name = 'masa')
);

INSERT INTO credit_cards (
  liability_account_id, bank_account_id, cutoff_day, payment_day, user_id
) VALUES (
  (SELECT id FROM liability_accounts WHERE name = 'JAL'),
  (SELECT id FROM asset_accounts WHERE name = '三菱UFJ銀行 用賀出張所'),
  15,
  10,
  (SELECT id FROM users WHERE name = 'masa')
), (
  (SELECT id FROM liability_accounts WHERE name = 'enoteca'),
  (SELECT id FROM asset_accounts WHERE name = '三菱UFJ銀行 用賀出張所'),
  15,
  10,
  (SELECT id FROM users WHERE name = 'masa')
), (
  (SELECT id FROM liability_accounts WHERE name = 'tcard'),
  (SELECT id FROM asset_accounts WHERE name = '三菱UFJ銀行 用賀出張所'),
  10,
  27,
  (SELECT id FROM users WHERE name = 'masa')
), (
  (SELECT id FROM liability_accounts WHERE name = 'PayPay'),
  (SELECT id FROM asset_accounts WHERE name = 'みずほ銀行 玉川支店'),
  31,
  27,
  (SELECT id FROM users WHERE name = 'masa')
);

INSERT INTO equity_accounts (
  name, user_id
) VALUES (
  '元入金',
  (SELECT id FROM users WHERE name = 'masa')
);

