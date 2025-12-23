class User < ApplicationRecord
  has_many :expense_accounts
  has_many :liability_accounts
  has_many :asset_accounts
  has_many :equity_accounts
  has_many :credit_cards
end
