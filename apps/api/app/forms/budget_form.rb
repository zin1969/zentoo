# app/forms/budget_form.rb

# 予算の追加・変更（POST /budgets、PUT /budgets/:id）のリクエストを検証する。
# 対象（target_type）は 1 = 費用科目（expense_account_id）か 2 = タグ（tag_id）。使わない方は送られても無視する。
# 周期（period_type）は 1 = 週、2 = 月、3 = 年。月だけ、1〜12 月で月ごとに決めた額（monthly_amounts）を持てる。
class BudgetForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  TARGET_TYPES = [ Budget::TARGET_EXPENSE_ACCOUNT, Budget::TARGET_TAG ].freeze
  PERIOD_TYPES = [ Budget::PERIOD_WEEK, Budget::PERIOD_MONTH, Budget::PERIOD_YEAR ].freeze
  # DB の金額・ID（INT）に収まる上限
  MAX_INT = 2_147_483_647
  MAX_NAME_LENGTH = 30
  MAX_EXCLUDED_TAGS = 10
  MONTHS = 12

  attribute :name, :string
  attribute :target_type
  attribute :expense_account_id
  attribute :tag_id
  attribute :period_type
  # 1 回の期間の額。月ごとに決めた額があるときは使わない（送らなくてよい）
  attribute :amount
  attribute :monthly_amounts
  # 科目の予算から外すタグ（任意）
  attribute :excluded_tag_ids, default: -> { [] }

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validate :validate_target
  validate :validate_period_and_amounts
  validate :validate_excluded_tag_ids

  def name=(value)
    super(value.is_a?(String) ? value.strip : value)
  end

  def expense_account_target?
    target_type == Budget::TARGET_EXPENSE_ACCOUNT
  end

  def to_attributes
    {
      name: name,
      target_type: target_type,
      expense_account_id: expense_account_target? ? expense_account_id : nil,
      tag_id: expense_account_target? ? nil : tag_id,
      period_type: period_type,
      amount: monthly_amounts_given? ? 0 : amount,
      monthly_amounts: monthly_amounts_given? ? monthly_amounts : nil
    }
  end

  # 除くタグは科目の予算だけ。同じタグを 2 回送っても 1 つにする
  def excluded_tag_id_list
    expense_account_target? ? Array(excluded_tag_ids).uniq : []
  end

  private

  def positive_int?(value)
    value.is_a?(Integer) && value.between?(1, MAX_INT)
  end

  def amount?(value)
    value.is_a?(Integer) && value.between?(0, MAX_INT)
  end

  def monthly_amounts_given?
    period_type == Budget::PERIOD_MONTH && !monthly_amounts.nil?
  end

  def validate_target
    return errors.add(:target_type, "must be 1 (expense account) or 2 (tag)") unless TARGET_TYPES.include?(target_type)

    if expense_account_target?
      errors.add(:expense_account_id, "must be a positive integer") unless positive_int?(expense_account_id)
    else
      errors.add(:tag_id, "must be a positive integer") unless positive_int?(tag_id)
    end
  end

  def validate_period_and_amounts
    return errors.add(:period_type, "must be 1 (week), 2 (month) or 3 (year)") unless PERIOD_TYPES.include?(period_type)

    if monthly_amounts.nil?
      errors.add(:amount, "must be an integer between 0 and #{MAX_INT}") unless amount?(amount)
    elsif period_type != Budget::PERIOD_MONTH
      errors.add(:monthly_amounts, "can only be set for a monthly budget")
    elsif !(monthly_amounts.is_a?(Array) && monthly_amounts.size == MONTHS && monthly_amounts.all? { |a| amount?(a) })
      errors.add(:monthly_amounts, "must be #{MONTHS} integers between 0 and #{MAX_INT} (January to December)")
    end
  end

  def validate_excluded_tag_ids
    return unless expense_account_target?

    ids = excluded_tag_ids
    return if ids.is_a?(Array) && ids.size <= MAX_EXCLUDED_TAGS && ids.all? { |id| positive_int?(id) }

    errors.add(:excluded_tag_ids, "must be up to #{MAX_EXCLUDED_TAGS} positive integers")
  end
end
