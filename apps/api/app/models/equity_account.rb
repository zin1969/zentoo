class EquityAccount < ApplicationRecord
  # user_id が NULL の科目は全ユーザーが使える共通科目
  belongs_to :user, optional: true

  scope :available_to, ->(user) { where(user_id: [ nil, user.id ]) }
end
