module Journals
  class CreateOpeningAsset
    def self.create_opening_asset_balance_journal!(
      journal_date:,
      asset_type:,
      asset_account_id:,
      amount:,
      user_id:
    )
      sql = ActiveRecord::Base.send(
        :sanitize_sql_array,
        [
          <<~SQL,
            SELECT create_opening_asset_balance_journal(
              ?::date,
              ?::int,
              ?::int,
              ?::int,
              ?::int
            )
          SQL
          journal_date,
          asset_type,
          asset_account_id,
          amount,
          user_id
        ]
      )

      # Returns the ID of the created journal record
      ActiveRecord::Base.connection.select_value(sql)
    end
  end
end
