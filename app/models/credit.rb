class Credit < ApplicationRecord
  belongs_to :journal
  attribute :element_type, ElementTypeType.new
end
