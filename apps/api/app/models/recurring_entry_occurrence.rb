class RecurringEntryOccurrence < ApplicationRecord
  # 決まった支払いの 1 回分の記録（登録した仕訳か、飛ばしたか）。
  # 決まった支払いや仕訳が消えると、DB の外部キー（ON DELETE CASCADE）で消える
  belongs_to :recurring_entry
  belongs_to :journal, optional: true
end
