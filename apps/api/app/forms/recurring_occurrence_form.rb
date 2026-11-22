# app/forms/recurring_occurrence_form.rb

# 決まった支払いの回の登録・飛ばす（POST /recurring-entries/:id/occurrences、/skips）のリクエストを検証する。
# 金額は登録のときだけ（valid?(:register)）確かめる
class RecurringOccurrenceForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  # DB 関数の金額（INT）に収まる上限
  MAX_AMOUNT = 2_147_483_647

  attribute :scheduled_date, :date
  # 仕訳の日付。省略すると予定日（予定日より遅れて払ったときに変える）
  attribute :date, :date
  attribute :amount

  validates :scheduled_date, presence: true
  validate :validate_amount, on: :register

  private

  def validate_amount
    return if amount.is_a?(Integer) && amount.between?(1, MAX_AMOUNT)

    errors.add(:amount, "must be an integer between 1 and #{MAX_AMOUNT}")
  end
end
