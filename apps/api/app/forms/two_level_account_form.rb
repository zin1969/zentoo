# app/forms/two_level_account_form.rb

# 親子 2 階層の科目の追加・変更（POST・PUT /expense-accounts、/revenue-accounts）のリクエストを検証する。
# parent_id を省略するか null にすると、親の無い（トップレベルの）科目になる。
class TwoLevelAccountForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  MAX_NAME_LENGTH = 50

  attribute :name, :string
  attribute :parent_id

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validate :validate_parent_id

  def name=(value)
    super(value.is_a?(String) ? value.strip : value)
  end

  private

  def validate_parent_id
    return if parent_id.nil? || (parent_id.is_a?(Integer) && parent_id.positive?)

    errors.add(:parent_id, "must be a positive integer or null")
  end
end
