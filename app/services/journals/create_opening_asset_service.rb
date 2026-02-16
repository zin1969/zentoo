module Journals
  class CreateOpeningAssetService
    def initialize(
      repository: CreateOpeningAsset.new
    )
      @repository = repository
    end

    def call(
      journal_date:,
      asset_type:,
      asset_account_id:,
      amount:,
      user_id:
    )
      ActiveRecord::Base.transaction do
        @repository.create_opening_asset_balance!(
          journal_date:,
          asset_type:,
          asset_account_id:,
          amount:,
          user_id:
        )
      end
    end
  end
end
