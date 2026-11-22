# --- 借方（debits）の1行分を管理するクラス ---
class DebitEntryForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  MAX_TAGS = 10
  MAX_TAX_RATE = 100

  # 作成いただいたカスタム型をここで指定！
  attribute :element_type
  attribute :account_id, :integer
  attribute :amount
  attribute :item_name, :string
  # 明細に付けるタグ（本人のタグの ID）。費用の明細にだけ付けられる（DB 関数が確かめる）
  attribute :tag_ids, default: -> { [] }
  # 外税のレシートで登録した明細の、税率（整数の %）と税抜の金額。amount は税込。内税の明細はどちらも省く
  attribute :tax_rate
  attribute :tax_excluded_amount

  validates :element_type, :account_id, :amount, presence: true
  validate :validate_types
  validate :validate_tag_ids
  validate :validate_tax

  private

  def validate_types
    errors.add(:element_type, "must be an ElementType") unless element_type.is_a?(ElementType)
    errors.add(:amount, "must be an Amount") unless amount.is_a?(Amount)
  end

  def validate_tax
    return if tax_rate.nil? && tax_excluded_amount.nil?

    unless tax_rate.is_a?(Integer) && tax_rate.between?(0, MAX_TAX_RATE)
      errors.add(:tax_rate, "must be an integer between 0 and #{MAX_TAX_RATE}")
    end

    # 税抜の金額は、税込の金額（amount）を超えない
    max = amount.is_a?(Amount) ? amount.to_i : 0
    return if tax_excluded_amount.is_a?(Integer) && tax_excluded_amount.between?(0, max)

    errors.add(:tax_excluded_amount, "must be an integer between 0 and the amount")
  end

  def validate_tag_ids
    valid = tag_ids.is_a?(Array) && tag_ids.size <= MAX_TAGS && tag_ids.all? { |id| id.is_a?(Integer) && id.positive? }
    errors.add(:tag_ids, "must be an array of up to #{MAX_TAGS} positive integers") unless valid
  end
end
