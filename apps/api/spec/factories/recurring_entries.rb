FactoryBot.define do
  # 既定は「毎月 27 日の家賃」。科目の ID は、使う spec で実在の科目に差し替える
  factory :recurring_entry do
    association :user
    name { "家賃" }
    kind { 1 }
    amount { 85_000 }
    debit_account_id { 1 }
    credit_element_type { 1 }
    credit_account_id { 1 }
    interval_unit { 1 }
    interval_count { 1 }
    day_of_month { 27 }
    start_date { Date.new(2026, 11, 1) }
  end
end
