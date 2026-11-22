# app/forms/income_journal_form.rb

# 収入の登録・修正（POST /income-journals、PUT /income-journals/:id）のリクエストを検証する。
class IncomeJournalForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  # DB 関数の金額（INT）に収まる上限
  MAX_AMOUNT = 2_147_483_647
  MAX_DESCRIPTION_LENGTH = 100

  attribute :journal_date, :date
  attribute :asset_account_id
  attribute :revenue_account_id
  attribute :amount
  # 支払元など。空なら DB 関数が収益科目の名前を入れる
  attribute :description, :string

  validates :journal_date, presence: true
  validates :description, length: { maximum: MAX_DESCRIPTION_LENGTH }
  validate :validate_account_ids
  validate :validate_amount

  private

  def validate_account_ids
    { asset_account_id: asset_account_id, revenue_account_id: revenue_account_id }.each do |attribute, value|
      next if value.is_a?(Integer) && value.positive?

      errors.add(attribute, "must be a positive integer")
    end
  end

  def validate_amount
    return if amount.is_a?(Integer) && amount.between?(1, MAX_AMOUNT)

    errors.add(:amount, "must be an integer between 1 and #{MAX_AMOUNT}")
  end
end
