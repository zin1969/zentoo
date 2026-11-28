# app/forms/create_opening_asset_balance_journal_form.rb

class CreateOpeningAssetBalanceJournalForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  # DB 関数の株数（INT）に収まる上限
  MAX_SHARES = 2_147_483_647

  attribute :journal_date, :date
  attribute :asset_type
  attribute :asset_account_id, :integer
  attribute :amount
  # 株の銘柄の開始残高のときだけ渡す（任意）
  attribute :shares

  validates :journal_date, presence: true
  validates :asset_account_id, presence: true

  validate :validate_asset_type
  validate :validate_amount
  validate :validate_shares

  private

  def validate_asset_type
    return if asset_type.is_a?(ElementType)

    errors.add(:asset_type, "must be an ElementType")
  end

  def validate_amount
    return if amount.is_a?(Amount)

    errors.add(:amount, "must be an Amount")
  end

  def validate_shares
    return if shares.nil?
    return if shares.is_a?(Integer) && shares.between?(1, MAX_SHARES)

    errors.add(:shares, "must be an integer between 1 and #{MAX_SHARES}")
  end
end
