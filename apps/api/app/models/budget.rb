class Budget < ApplicationRecord
  # 予算（M20）。費用科目かタグごとに、週・月・年の額を決める。ユーザーごと
  TARGET_EXPENSE_ACCOUNT = 1
  TARGET_TAG = 2

  PERIOD_WEEK = 1
  PERIOD_MONTH = 2
  PERIOD_YEAR = 3

  belongs_to :user
  belongs_to :expense_account, optional: true
  belongs_to :tag, optional: true
  # 科目の予算から外すタグ（DB の ON DELETE CASCADE で一緒に消える）
  has_many :budget_excluded_tags
  has_many :excluded_tags, through: :budget_excluded_tags, source: :tag
end
