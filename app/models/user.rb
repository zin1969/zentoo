class User < ApplicationRecord
  has_many :expense_accounts
end
