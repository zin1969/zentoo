class Debit < ApplicationRecord
  belongs_to :journal
  has_many :debit_tags
  has_many :tags, through: :debit_tags
  attribute :element_type, ElementTypeType.new
  attribute :amount, AmountType.new
end
