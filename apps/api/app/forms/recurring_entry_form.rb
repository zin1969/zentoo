# app/forms/recurring_entry_form.rb

# 決まった支払いの追加・変更（POST /recurring-entries、PUT /recurring-entries/:id）のリクエストを検証する。
class RecurringEntryForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  KIND_EXPENSE = 1
  KIND_INCOME = 2
  # 支出の支払い方法は資産か負債、収入の相手は収益
  CREDIT_ELEMENT_TYPES = {
    KIND_EXPENSE => [ ElementType::ASSETS, ElementType::LIABILITIES ],
    KIND_INCOME => [ ElementType::REVENUE ]
  }.freeze
  INTERVAL_UNIT_MONTH = 1
  INTERVAL_UNIT_WEEK = 2
  MAX_INTERVAL_COUNT = 12
  # 31 は月末（月に無い日は月末にするため）
  MAX_DAY_OF_MONTH = 31
  # 0 = 日曜 … 6 = 土曜
  MAX_WEEKDAY = 6
  # DB 関数の金額（INT）に収まる上限
  MAX_AMOUNT = 2_147_483_647
  MAX_NAME_LENGTH = 30
  MAX_TEXT_LENGTH = 100

  attribute :name, :string
  attribute :kind
  attribute :store_name, :string
  attribute :item_name, :string
  attribute :amount
  attribute :debit_account_id
  attribute :credit_element_type
  attribute :credit_account_id
  attribute :interval_unit
  attribute :interval_count
  attribute :day_of_month
  attribute :weekday
  attribute :start_date, :date
  attribute :end_date, :date

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validates :store_name, :item_name, length: { maximum: MAX_TEXT_LENGTH }
  validates :start_date, presence: true
  validate :validate_kind
  validate :validate_amount
  validate :validate_account_ids
  validate :validate_schedule
  validate :validate_period

  def name=(value)
    super(value.is_a?(String) ? value.strip : value)
  end

  def to_attributes
    {
      name: name, kind: kind, store_name: store_name.presence, item_name: item_name.presence, amount: amount,
      debit_account_id: debit_account_id, credit_element_type: credit_element_type, credit_account_id: credit_account_id,
      interval_unit: interval_unit, interval_count: interval_count,
      day_of_month: monthly? ? day_of_month : nil, weekday: monthly? ? nil : weekday,
      start_date: start_date, end_date: end_date
    }
  end

  private

  def monthly?
    interval_unit == INTERVAL_UNIT_MONTH
  end

  def validate_kind
    allowed = CREDIT_ELEMENT_TYPES[kind]
    return errors.add(:kind, "must be 1 (expense) or 2 (income)") if allowed.nil?
    return if allowed.include?(credit_element_type)

    errors.add(:credit_element_type, "must be one of #{allowed.join(', ')} for this kind")
  end

  def validate_amount
    return if amount.is_a?(Integer) && amount.between?(1, MAX_AMOUNT)

    errors.add(:amount, "must be an integer between 1 and #{MAX_AMOUNT}")
  end

  def validate_account_ids
    { debit_account_id: debit_account_id, credit_account_id: credit_account_id }.each do |attribute, value|
      next if value.is_a?(Integer) && value.positive?

      errors.add(attribute, "must be a positive integer")
    end
  end

  # 月単位は日（day_of_month）、週単位は曜日（weekday）を使う。使わない方は送られても無視する
  def validate_schedule
    unless [ INTERVAL_UNIT_MONTH, INTERVAL_UNIT_WEEK ].include?(interval_unit)
      return errors.add(:interval_unit, "must be 1 (month) or 2 (week)")
    end

    unless interval_count.is_a?(Integer) && interval_count.between?(1, MAX_INTERVAL_COUNT)
      errors.add(:interval_count, "must be an integer between 1 and #{MAX_INTERVAL_COUNT}")
    end

    if monthly?
      return if day_of_month.is_a?(Integer) && day_of_month.between?(1, MAX_DAY_OF_MONTH)

      errors.add(:day_of_month, "must be an integer between 1 and #{MAX_DAY_OF_MONTH}")
    else
      return if weekday.is_a?(Integer) && weekday.between?(0, MAX_WEEKDAY)

      errors.add(:weekday, "must be an integer between 0 (Sunday) and #{MAX_WEEKDAY} (Saturday)")
    end
  end

  def validate_period
    return if end_date.nil? || start_date.nil? || end_date >= start_date

    errors.add(:end_date, "must be on or after the start date")
  end
end
