# frozen_string_literal: true

module Reports
  # 預金口座の通帳（繰越と、期間内の出入金。未来の引き落とし予定を含む）
  class BankAccountLedgerService
    class AssetAccountNotFound < StandardError; end

    def initialize(repository: BankAccountLedger.new)
      @repository = repository
    end

    # @param from [Date, nil] 省略すると先月の初め
    # @param to [Date, nil] 省略すると、口座の最後の予定日（今月末より前なら今月末）
    def call(user:, asset_account_id:, from:, to:)
      account = user.asset_accounts.deposit.find_by(id: asset_account_id)
      raise AssetAccountNotFound unless account

      today = Date.current
      from ||= today.prev_month.beginning_of_month
      to ||= default_to(user, account, today)

      rows = @repository.list(user_id: user.id, asset_account_id: account.id, from: from, to: to)
      purchases = original_purchases(user, rows)

      {
        account: { id: account.id, name: account.name },
        from: from,
        to: to,
        today: today,
        entries: rows.map { |row| present(row, today, purchases) }
      }
    rescue BankAccountLedger::AssetAccountNotFound
      raise AssetAccountNotFound
    end

    private

    def default_to(user, account, today)
      [ today.end_of_month, @repository.last_entry_date(user_id: user.id, asset_account_id: account.id) ].compact.max
    end

    def present(row, today, purchases)
      {
        row_type: row.row_type,
        date: row.entry_date,
        description: row.description,
        deposit: row.deposit,
        withdrawal: row.withdrawal,
        balance: row.balance,
        # 今日より後の行は、まだ引き落とされていない予定
        scheduled: row.row_type != "carried_over" && row.entry_date > today,
        # カードの行は、まとめたカードと、元のお買い物の内訳
        card_account_id: row.card_account_id,
        journal_ids: row.journal_ids,
        items: row.row_type == "card_payment" ? card_payment_items(row, purchases) : []
      }
    end

    # カードの行の、元のお買い物の仕訳
    #
    # @return [Hash{Integer => Journal}]
    def original_purchases(user, rows)
      ids = rows.select { |row| row.row_type == "card_payment" }.flat_map(&:journal_ids)
      return {} if ids.empty?

      Journal.where(user_id: user.id, id: ids).includes(:credits).index_by(&:id)
    end

    # カードの行を開いたときの内訳。お買い物 1 件ごとの、そのカードで払った額
    def card_payment_items(row, purchases)
      row.journal_ids.filter_map { |id| purchases[id] }.map do |journal|
        amount = journal.credits
                        .select { |credit| credit.element_type.to_i == ElementType::LIABILITIES && credit.account_id == row.card_account_id }
                        .sum { |credit| credit.amount.to_i }

        { journal_id: journal.id, journal_date: journal.journal_dt, store_name: journal.store_name, amount: amount }
      end
    end
  end
end
