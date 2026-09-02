class Journal < ApplicationRecord
  has_many :debits
  has_many :credits
end
