# app/forms/tag_report_form.rb

# タグの集計 API のクエリパラメータを検証する。
# 月ごとの合計（GET /tag-reports/:id）は year（YYYY）、月の明細（GET /tag-reports/:id/items）は month（YYYY-MM）を使う。
class TagReportForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  YEARS = (2000..2100)

  attribute :year, :string
  attribute :month, :string

  validate :validate_year
  validate :validate_month

  # 省略した場合は今年（日本時間）
  def target_year
    year.present? ? year.to_i : Date.current.year
  end

  # 省略した場合は今月（日本時間）。月の初日を返す
  def month_start
    parsed_month || Date.current.beginning_of_month
  end

  private

  def parsed_month
    return if month.blank?
    return unless month.match?(/\A\d{4}-(0[1-9]|1[0-2])\z/)

    Date.new(*month.split("-").map(&:to_i), 1)
  end

  def validate_year
    return if year.blank?
    return if year.match?(/\A\d{4}\z/) && YEARS.cover?(year.to_i)

    errors.add(:year, "must be a year between #{YEARS.first} and #{YEARS.last}")
  end

  def validate_month
    errors.add(:month, "must be a month (YYYY-MM)") if month.present? && parsed_month.nil?
  end
end
