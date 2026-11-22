class Tag < ApplicationRecord
  # 「何のために使ったか」（勉強・娯楽など）。ユーザーごと
  belongs_to :user
  has_many :debit_tags
end
