# app/forms/account_balances_form.rb

# 残高 API のクエリパラメータ（基準日）を検証する。
class AccountBalancesForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :date, :string

  validate :validate_date

  # 省略した場合は今日
  def as_of_date
    parsed_date || Date.current
  end

  private

  def parsed_date
    return if date.blank?

    Date.iso8601(date)
  rescue Date::Error
    nil
  end

  def validate_date
    errors.add(:date, "must be a date (YYYY-MM-DD)") if date.present? && parsed_date.nil?
  end
end
