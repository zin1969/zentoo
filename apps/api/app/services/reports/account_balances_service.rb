# frozen_string_literal: true

module Reports
  class AccountBalancesService
    def initialize(repository: AccountBalances.new)
      @repository = repository
    end

    def call(user_id:, as_of:)
      balances = @repository.list(user_id: user_id, as_of: as_of)

      assets = present(balances, ElementType::ASSETS)
      liabilities = present(balances, ElementType::LIABILITIES)
      total_assets = assets.sum { |account| account[:balance] }
      total_liabilities = liabilities.sum { |account| account[:balance] }

      {
        date: as_of,
        assets: assets,
        liabilities: liabilities,
        total_assets: total_assets,
        total_liabilities: total_liabilities,
        net_assets: total_assets - total_liabilities
      }
    end

    private

    def present(balances, element_type)
      balances
        .select { |balance| balance.element_type == element_type }
        .map { |balance| { account_id: balance.account_id, account_name: balance.account_name, balance: balance.balance } }
    end
  end
end
