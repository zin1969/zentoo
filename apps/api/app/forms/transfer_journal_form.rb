# app/forms/transfer_journal_form.rb

# 振替の登録・修正（POST /transfer-journals、PUT /transfer-journals/:id）のリクエストを検証する。
# 出す元は from_type で、口座（"asset"）かクレジットカード（"credit_card"）かを指定する。
class TransferJournalForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  # DB 関数の金額（INT）に収まる上限
  MAX_AMOUNT = 2_147_483_647
  MAX_DESCRIPTION_LENGTH = 100

  FROM_ELEMENT_TYPES = {
    "asset" => ElementType::ASSETS,
    "credit_card" => ElementType::LIABILITIES
  }.freeze

  attribute :journal_date, :date
  attribute :from_type, :string
  attribute :from_account_id
  attribute :to_account_id
  attribute :amount
  # 空なら DB 関数が組み合わせから摘要を決める（引き出し・預入・チャージ・振替）
  attribute :description, :string

  validates :journal_date, presence: true
  validates :from_type, inclusion: { in: FROM_ELEMENT_TYPES.keys, message: "must be asset or credit_card" }
  validates :description, length: { maximum: MAX_DESCRIPTION_LENGTH }
  validate :validate_account_ids
  validate :validate_amount

  def from_element_type
    FROM_ELEMENT_TYPES.fetch(from_type)
  end

  private

  def validate_account_ids
    { from_account_id: from_account_id, to_account_id: to_account_id }.each do |attribute, value|
      next if value.is_a?(Integer) && value.positive?

      errors.add(attribute, "must be a positive integer")
    end
  end

  def validate_amount
    return if amount.is_a?(Integer) && amount.between?(1, MAX_AMOUNT)

    errors.add(:amount, "must be an integer between 1 and #{MAX_AMOUNT}")
  end
end
