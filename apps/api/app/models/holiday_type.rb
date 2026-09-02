class HolidayType < ApplicationRecord
  has_many :holidays, dependent: :restrict_with_exception
end
