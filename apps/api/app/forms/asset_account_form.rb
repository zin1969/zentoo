# app/forms/asset_account_form.rb

# 口座の追加・変更（POST /asset-accounts、PUT /asset-accounts/:id）のリクエストを検証する。
# asset_type は、口座の一覧の payment_method_type と同じ数値
# （1: 現金、2: 預金、3: 電子マネー、4: 証券口座、5: 投資）で受け取る。
class AssetAccountForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  MAX_NAME_LENGTH = 50

  attribute :name, :string
  attribute :asset_type

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validate :validate_asset_type

  def name=(value)
    super(value.is_a?(String) ? value.strip : value)
  end

  # @return [String] AssetAccount.asset_types のキー
  def asset_type_key
    AssetAccount.asset_types.key(asset_type)
  end

  private

  def validate_asset_type
    return if asset_type.is_a?(Integer) && asset_type_key

    errors.add(:asset_type, "must be 1 (cash), 2 (deposit), 3 (e_money), 4 (securities) or 5 (investment)")
  end
end
