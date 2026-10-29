# app/forms/list_journals_form.rb

# 仕訳一覧のクエリパラメータ（期間とページ）を検証する。
class ListJournalsForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :from, :string
  attribute :to, :string
  attribute :page, :string

  validate :validate_from
  validate :validate_to
  validate :validate_period_order
  validate :validate_page

  def from_date
    parse_date(from)
  end

  def to_date
    parse_date(to)
  end

  def page_number
    page.presence ? page.to_i : 1
  end

  private

  def validate_from
    errors.add(:from, "must be a date (YYYY-MM-DD)") if from.present? && from_date.nil?
  end

  def validate_to
    errors.add(:to, "must be a date (YYYY-MM-DD)") if to.present? && to_date.nil?
  end

  def validate_period_order
    return unless from_date && to_date && from_date > to_date

    errors.add(:to, "must not be earlier than from")
  end

  def validate_page
    return if page.blank? || page.match?(/\A[1-9]\d*\z/)

    errors.add(:page, "must be an integer of 1 or greater")
  end

  def parse_date(value)
    return if value.blank?

    Date.iso8601(value)
  rescue Date::Error
    nil
  end
end
