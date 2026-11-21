# app/forms/credit_card_form.rb

# クレジットカードの追加・変更（POST /credit-cards、PUT /credit-cards/:id）のリクエストを検証する。
class CreditCardForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  MAX_NAME_LENGTH = 50

  attribute :name, :string
  attribute :cutoff_day
  attribute :payment_day
  attribute :bank_account_id

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validate :validate_days
  validate :validate_bank_account_id

  def name=(value)
    super(value.is_a?(String) ? value.strip : value)
  end

  private

  # 月に無い日（31 日締めの 2 月など）は、DB 関数が月末に丸める
  def validate_days
    { cutoff_day: cutoff_day, payment_day: payment_day }.each do |attribute, value|
      next if value.is_a?(Integer) && value.between?(1, 31)

      errors.add(attribute, "must be an integer between 1 and 31")
    end
  end

  def validate_bank_account_id
    return if bank_account_id.is_a?(Integer) && bank_account_id.positive?

    errors.add(:bank_account_id, "must be a positive integer")
  end
end
