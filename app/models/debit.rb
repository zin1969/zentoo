class Debit < ApplicationRecord
  belongs_to :journal
  attribute :element_type, ElementTypeType.new
  attribute :amount, AmountType.new
end
