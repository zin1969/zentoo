class RecurringEntry < ApplicationRecord
  # 決まった支払い（家賃・サブスク・給料など）。回ごとに確かめてから仕訳にする。ユーザーごと
  belongs_to :user
  has_many :recurring_entry_occurrences
end
