class BudgetExcludedTag < ApplicationRecord
  # 科目の予算から外すタグ（例: 食費の予算から、タグ「アルコール」の付いた明細を外す）
  belongs_to :budget
  belongs_to :tag
end
