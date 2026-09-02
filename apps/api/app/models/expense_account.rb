class ExpenseAccount < ApplicationRecord
  belongs_to :user
  belongs_to :parent, class_name: "ExpenseAccount", optional: true
end
