# --- 借方（debits）の1行分を管理するクラス ---
class DebitEntryForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  MAX_TAGS = 10

  # 作成いただいたカスタム型をここで指定！
  attribute :element_type
  attribute :account_id, :integer
  attribute :amount
  attribute :item_name, :string
  # 明細に付けるタグ（本人のタグの ID）。費用の明細にだけ付けられる（DB 関数が確かめる）
  attribute :tag_ids, default: -> { [] }

  validates :element_type, :account_id, :amount, presence: true
  validate :validate_types
  validate :validate_tag_ids

  private

  def validate_types
    errors.add(:element_type, "must be an ElementType") unless element_type.is_a?(ElementType)
    errors.add(:amount, "must be an Amount") unless amount.is_a?(Amount)
  end

  def validate_tag_ids
    valid = tag_ids.is_a?(Array) && tag_ids.size <= MAX_TAGS && tag_ids.all? { |id| id.is_a?(Integer) && id.positive? }
    errors.add(:tag_ids, "must be an array of up to #{MAX_TAGS} positive integers") unless valid
  end
end
