# app/forms/create_opening_asset_balance_journal_form.rb
class CreateOpeningAssetBalanceJournalForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :journal_date, :date
  attribute :asset_type
  attribute :asset_account_id, :integer
  attribute :amount

  validates :journal_date, presence: true
  validates :asset_account_id, presence: true

  validate :validate_asset_type
  validate :validate_amount

  private

  def validate_asset_type
    return if asset_type.is_a?(ElementType)

    errors.add(:asset_type, 'must be an ElementType')
  end

  def validate_amount
    return if amount.is_a?(Amount)

    errors.add(:amount, 'must be an Amount')
  end
end
