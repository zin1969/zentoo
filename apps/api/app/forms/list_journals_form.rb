# app/forms/list_journals_form.rb

# 仕訳一覧のクエリパラメータ（期間・ページと、検索の条件）を検証する。
class ListJournalsForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  ELEMENT_TYPES = (1..5).to_a.freeze
  POSITIVE_INTEGER = /\A[1-9]\d*\z/

  attribute :from, :string
  attribute :to, :string
  attribute :page, :string
  attribute :q, :string
  attribute :element_type, :string
  attribute :account_id, :string
  attribute :tag_id, :string

  validate :validate_from
  validate :validate_to
  validate :validate_period_order
  validate :validate_page
  validate :validate_account
  validate :validate_tag_id

  def from_date
    parse_date(from)
  end

  def to_date
    parse_date(to)
  end

  def page_number
    page.presence ? page.to_i : 1
  end

  # 前後の空白を除いたキーワード。空なら nil（キーワードで絞らない）
  def keyword
    q&.strip.presence
  end

  # 科目の指定 { element_type:, account_id: }。指定が無ければ nil
  def account
    return if account_id.blank?

    { element_type: element_type.to_i, account_id: account_id.to_i }
  end

  def tag
    tag_id.presence&.to_i
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
    return if page.blank? || page.match?(POSITIVE_INTEGER)

    errors.add(:page, "must be an integer of 1 or greater")
  end

  # 科目の ID は要素（資産・負債など）ごとの表の ID なので、element_type と組で指定する
  def validate_account
    return if element_type.blank? && account_id.blank?

    if element_type.blank? || account_id.blank?
      errors.add(:account_id, "must be given together with element_type")
      return
    end

    errors.add(:element_type, "must be one of 1 to 5") unless element_type.match?(POSITIVE_INTEGER) && ELEMENT_TYPES.include?(element_type.to_i)
    errors.add(:account_id, "must be an integer of 1 or greater") unless account_id.match?(POSITIVE_INTEGER)
  end

  def validate_tag_id
    return if tag_id.blank? || tag_id.match?(POSITIVE_INTEGER)

    errors.add(:tag_id, "must be an integer of 1 or greater")
  end

  def parse_date(value)
    return if value.blank?

    Date.iso8601(value)
  rescue Date::Error
    nil
  end
end
