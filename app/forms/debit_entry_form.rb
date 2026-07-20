# --- 借方（debits）の1行分を管理するクラス ---
class DebitEntryForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  # 作成いただいたカスタム型をここで指定！
  attribute :element_type
  attribute :account_id, :integer
  attribute :amount
  attribute :item_name, :string

  validates :element_type, :account_id, :amount, presence: true
  validate :validate_types

  private

  def validate_types
    errors.add(:element_type, 'must be an ElementType') unless element_type.is_a?(ElementType)
    errors.add(:amount, 'must be an Amount') unless amount.is_a?(Amount)
  end
end
