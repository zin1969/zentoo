# app/forms/monthly_expenses_form.rb

# 月次支出 API のクエリパラメータ（対象月）を検証する。
class MonthlyExpensesForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  MONTH_FORMAT = /\A\d{4}-(0[1-9]|1[0-2])\z/

  attribute :month, :string

  validate :validate_month

  # 対象月の 1 日。省略した場合は今月
  def month_start
    return Date.current.beginning_of_month if month.blank?

    Date.iso8601("#{month}-01")
  end

  private

  def validate_month
    return if month.blank? || month.match?(MONTH_FORMAT)

    errors.add(:month, "must be a month (YYYY-MM)")
  end
end
