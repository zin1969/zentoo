class DebitTag < ApplicationRecord
  # 明細（借方の 1 行）とタグの組。明細やタグが消えると、DB の外部キー（ON DELETE CASCADE）で消える
  belongs_to :debit
  belongs_to :tag
end
