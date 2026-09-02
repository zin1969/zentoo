class CreditCard < ApplicationRecord
  belongs_to :liability_account
  belongs_to :bank_account, class_name: "AssetAccount"
  belongs_to :user
end
