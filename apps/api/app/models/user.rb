class User < ApplicationRecord
  # password_digest が NULL のユーザー（system 等）を作れるよう、presence 検証は行わない
  has_secure_password validations: false

  has_many :expense_accounts
  has_many :liability_accounts
  has_many :asset_accounts
  has_many :equity_accounts
  has_many :credit_cards
end
