# app/forms/stock_trade_form.rb

# 株の売買の登録（POST /stock-trades）のリクエストを検証する。
# 金額は、買いなら証券口座から出ていった額（手数料を含む）、売りなら証券口座に入った額（手数料・税金を引いたあと）。
class StockTradeForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  # DB 関数の株数・金額（INT）に収まる上限
  MAX_INT = 2_147_483_647
  TRADE_TYPES = %w[buy sell].freeze

  attribute :trade_type, :string
  attribute :journal_date, :date
  attribute :stock_account_id
  attribute :securities_account_id
  attribute :shares
  attribute :amount

  validates :trade_type, inclusion: { in: TRADE_TYPES, message: "must be buy or sell" }
  validates :journal_date, presence: true
  validate :validate_positive_integers

  private

  def validate_positive_integers
    {
      stock_account_id: stock_account_id,
      securities_account_id: securities_account_id,
      shares: shares,
      amount: amount
    }.each do |attribute, value|
      next if value.is_a?(Integer) && value.between?(1, MAX_INT)

      errors.add(attribute, "must be an integer between 1 and #{MAX_INT}")
    end
  end
end
