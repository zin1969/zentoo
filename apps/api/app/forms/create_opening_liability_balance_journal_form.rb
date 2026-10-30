# app/forms/create_opening_liability_balance_journal_form.rb

# 開始負債（POST /liability-opening-journals）のリクエストを検証する。
class CreateOpeningLiabilityBalanceJournalForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  # DB 関数の金額（INT）に収まる上限
  MAX_AMOUNT = 2_147_483_647

  attribute :journal_date, :date
  attribute :liability_account_id
  attribute :amount
  attribute :payment_date, :date

  validates :journal_date, :payment_date, presence: true
  validate :validate_liability_account_id
  validate :validate_amount

  private

  def validate_liability_account_id
    return if liability_account_id.is_a?(Integer) && liability_account_id.positive?

    errors.add(:liability_account_id, "must be a positive integer")
  end

  def validate_amount
    return if amount.is_a?(Integer) && amount.between?(1, MAX_AMOUNT)

    errors.add(:amount, "must be an integer between 1 and #{MAX_AMOUNT}")
  end
end
