# app/forms/bank_account_ledger_form.rb

# 通帳 API（GET /bank-account-ledgers/:id）のクエリパラメータ（期間）を検証する。
# 省略した日付は、サービスが既定の期間で補う。
class BankAccountLedgerForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :from, :string
  attribute :to, :string

  validate :validate_dates

  def from_date
    parse(from)
  end

  def to_date
    parse(to)
  end

  private

  def parse(value)
    return if value.blank?

    Date.iso8601(value)
  rescue Date::Error
    nil
  end

  def validate_dates
    errors.add(:from, "must be a date (YYYY-MM-DD)") if from.present? && from_date.nil?
    errors.add(:to, "must be a date (YYYY-MM-DD)") if to.present? && to_date.nil?
    return unless from_date && to_date && to_date < from_date

    errors.add(:to, "must not be earlier than from")
  end
end
