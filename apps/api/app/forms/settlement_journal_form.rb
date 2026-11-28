# app/forms/settlement_journal_form.rb

# 立替金の精算の登録・修正（POST /settlement-journals、PUT /settlement-journals/:id）のリクエストを検証する。
# 差額（消し込む額 - 受け取った額）があるときは、差額の科目が要る（少なく受け取ったら費用科目、多く受け取ったら収益科目）。
class SettlementJournalForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  # DB 関数の金額・ID（INT）に収まる上限
  MAX_INT = 2_147_483_647
  MAX_DESCRIPTION_LENGTH = 100

  attribute :journal_date, :date
  attribute :receivable_account_id
  # 立替金から減らす額
  attribute :settled_amount
  # 受け取った額。全額おごりになったときは 0
  attribute :received_amount
  # 入金先の口座。受け取った額が 0 なら要らない
  attribute :to_account_id
  # 差額の科目。差額が無ければ要らない
  attribute :difference_account_id
  # 空なら DB 関数が「精算 立替金の口座名」にする
  attribute :description, :string

  validates :journal_date, presence: true
  validates :description, length: { maximum: MAX_DESCRIPTION_LENGTH }
  validate :validate_amounts
  validate :validate_account_ids

  # 差額は、渡されていても要らないときは使わない
  def to_account_id_or_nil
    received_amount.to_i.positive? ? to_account_id : nil
  end

  def difference_account_id_or_nil
    difference.to_i.zero? ? nil : difference_account_id
  end

  private

  def difference
    return nil unless integer_in?(settled_amount, 1) && integer_in?(received_amount, 0)

    settled_amount - received_amount
  end

  def integer_in?(value, min)
    value.is_a?(Integer) && value.between?(min, MAX_INT)
  end

  def validate_amounts
    errors.add(:settled_amount, "must be an integer between 1 and #{MAX_INT}") unless integer_in?(settled_amount, 1)
    errors.add(:received_amount, "must be an integer between 0 and #{MAX_INT}") unless integer_in?(received_amount, 0)
  end

  def validate_account_ids
    errors.add(:receivable_account_id, "must be a positive integer") unless integer_in?(receivable_account_id, 1)

    if received_amount.is_a?(Integer) && received_amount.positive? && !integer_in?(to_account_id, 1)
      errors.add(:to_account_id, "must be a positive integer when received_amount is positive")
    end

    if difference && !difference.zero? && !integer_in?(difference_account_id, 1)
      errors.add(:difference_account_id, "must be a positive integer when the amounts differ")
    end
  end
end
