# frozen_string_literal: true

puts '== HolidayType upsert =='

HolidayType.upsert_all(
  [
    { id: 1,  name: '元日' },
    { id: 2,  name: '成人の日' },
    { id: 3,  name: '建国記念の日' },
    { id: 4,  name: '天皇誕生日' },
    { id: 5,  name: '春分の日' },
    { id: 6,  name: '昭和の日' },
    { id: 7,  name: '憲法記念日' },
    { id: 8,  name: 'みどりの日' },
    { id: 9,  name: 'こどもの日' },
    { id: 10, name: '海の日' },
    { id: 11, name: '山の日' },
    { id: 12, name: '敬老の日' },
    { id: 13, name: '秋分の日' },
    { id: 14, name: 'スポーツの日' },
    { id: 15, name: '文化の日' },
    { id: 16, name: '勤労感謝の日' },
    { id: 17, name: '休日' },
    { id: 21, name: '銀行休日' }
  ]
)

puts '== Holiday upsert =='

Holiday.upsert_all(
  [
    # ---- 2025 ----
    { holiday: '2025-01-01', holiday_type_id: 1 },
    { holiday: '2025-01-02', holiday_type_id: 21 },
    { holiday: '2025-01-03', holiday_type_id: 21 },
    { holiday: '2025-01-13', holiday_type_id: 2 },
    { holiday: '2025-02-11', holiday_type_id: 3 },
    { holiday: '2025-02-23', holiday_type_id: 4 },
    { holiday: '2025-02-24', holiday_type_id: 17 },
    { holiday: '2025-03-20', holiday_type_id: 5 },
    { holiday: '2025-04-29', holiday_type_id: 6 },
    { holiday: '2025-05-03', holiday_type_id: 7 },
    { holiday: '2025-05-04', holiday_type_id: 8 },
    { holiday: '2025-05-05', holiday_type_id: 9 },
    { holiday: '2025-05-06', holiday_type_id: 17 },
    { holiday: '2025-07-21', holiday_type_id: 10 },
    { holiday: '2025-08-11', holiday_type_id: 11 },
    { holiday: '2025-09-15', holiday_type_id: 12 },
    { holiday: '2025-09-23', holiday_type_id: 13 },
    { holiday: '2025-10-13', holiday_type_id: 14 },
    { holiday: '2025-11-03', holiday_type_id: 15 },
    { holiday: '2025-11-23', holiday_type_id: 16 },
    { holiday: '2025-11-24', holiday_type_id: 17 },
    { holiday: '2025-12-31', holiday_type_id: 21 },

    # ---- 2026 ----
    { holiday: '2026-01-01', holiday_type_id: 1 },
    { holiday: '2026-01-02', holiday_type_id: 21 },
    { holiday: '2026-01-03', holiday_type_id: 21 },
    { holiday: '2026-01-12', holiday_type_id: 2 },
    { holiday: '2026-02-11', holiday_type_id: 3 },
    { holiday: '2026-02-23', holiday_type_id: 4 },
    { holiday: '2026-03-20', holiday_type_id: 5 },
    { holiday: '2026-04-29', holiday_type_id: 6 },
    { holiday: '2026-05-03', holiday_type_id: 7 },
    { holiday: '2026-05-04', holiday_type_id: 8 },
    { holiday: '2026-05-05', holiday_type_id: 9 },
    { holiday: '2026-05-06', holiday_type_id: 17 },
    { holiday: '2026-07-20', holiday_type_id: 10 },
    { holiday: '2026-08-11', holiday_type_id: 11 },
    { holiday: '2026-09-21', holiday_type_id: 12 },
    { holiday: '2026-09-22', holiday_type_id: 17 },
    { holiday: '2026-09-23', holiday_type_id: 13 },
    { holiday: '2026-10-12', holiday_type_id: 14 },
    { holiday: '2026-11-03', holiday_type_id: 15 },
    { holiday: '2026-11-23', holiday_type_id: 16 },
    { holiday: '2026-12-31', holiday_type_id: 21 }
  ],
  unique_by: :index_holidays_on_holiday
)
