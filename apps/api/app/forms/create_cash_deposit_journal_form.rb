# app/forms/create_cash_deposit_journal_form.rb

# 現金の預け入れ（POST /cash-deposit-journals）のリクエストを検証する。
class CreateCashDepositJournalForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  # DB 関数の金額（INT）に収まる上限
  MAX_AMOUNT = 2_147_483_647

  attribute :journal_date, :date
  attribute :bank_account_id
  attribute :amount

  validates :journal_date, presence: true
  validate :validate_bank_account_id
  validate :validate_amount

  private

  def validate_bank_account_id
    return if bank_account_id.is_a?(Integer) && bank_account_id.positive?

    errors.add(:bank_account_id, "must be a positive integer")
  end

  def validate_amount
    return if amount.is_a?(Integer) && amount.between?(1, MAX_AMOUNT)

    errors.add(:amount, "must be an integer between 1 and #{MAX_AMOUNT}")
  end
end
