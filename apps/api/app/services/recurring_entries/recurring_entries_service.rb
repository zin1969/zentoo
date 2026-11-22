# frozen_string_literal: true

module RecurringEntries
  # 決まった支払いの一覧・追加・変更・削除。決まった支払いはユーザーごと
  class RecurringEntriesService
    class NotFound < StandardError; end
    class AccountNotFound < StandardError; end

    Item = Struct.new(:entry, :debit_account_name, :credit_account_name, :next_date, keyword_init: true)

    KIND_EXPENSE = 1
    # 次の予定日を探す期間。月単位は 12 ヶ月ごとまでなので、1 年と少し先まで見れば必ず見つかる
    NEXT_DATE_SEARCH_DAYS = 400

    # 作った順に返す
    #
    # @return [Array<Item>] 決まった支払いと、科目の名前、今日以降の次の予定日（終了していれば nil）
    def list(user:, today: Date.current)
      entries = user.recurring_entries.order(:id).to_a

      entries.map do |entry|
        Item.new(
          entry: entry,
          debit_account_name: account_name(debit_element_type(entry), entry.debit_account_id),
          credit_account_name: account_name(entry.credit_element_type, entry.credit_account_id),
          next_date: next_date(entry, today)
        )
      end
    end

    def create!(user:, attributes:)
      check_accounts!(user, attributes)
      user.recurring_entries.create!(attributes)
    end

    def update!(user:, id:, attributes:)
      RecurringEntry.transaction do
        entry = lock!(user, id)
        check_accounts!(user, attributes)
        entry.update!(attributes)
        entry
      end
    end

    # 回の記録も消える（DB の ON DELETE CASCADE）。登録した仕訳は残る
    def destroy!(user:, id:)
      lock!(user, id).destroy!
    end

    private

    # 他ユーザーの決まった支払いと存在しないものは区別しない。同時に変更・削除されないよう、行をロックする
    def lock!(user, id)
      user.recurring_entries.lock.find_by(id: id) || raise(NotFound)
    end

    def debit_element_type(entry)
      entry.kind == KIND_EXPENSE ? ElementType::EXPENSES : ElementType::ASSETS
    end

    # 費用・収益科目は共通科目か本人の科目、口座とカードは本人のものだけ。他人の科目と存在しない科目は区別しない
    def check_accounts!(user, attributes)
      debit_type = attributes[:kind] == KIND_EXPENSE ? ElementType::EXPENSES : ElementType::ASSETS

      [ [ debit_type, attributes[:debit_account_id] ], [ attributes[:credit_element_type], attributes[:credit_account_id] ] ]
        .each { |type, id| raise AccountNotFound unless accounts_of(user, type).exists?(id: id) }
    end

    def accounts_of(user, element_type)
      case element_type
      when ElementType::ASSETS then user.asset_accounts
      when ElementType::LIABILITIES then user.liability_accounts
      when ElementType::REVENUE then RevenueAccount.available_to(user)
      when ElementType::EXPENSES then ExpenseAccount.available_to(user)
      end
    end

    def account_name(element_type, id)
      {
        ElementType::ASSETS => AssetAccount, ElementType::LIABILITIES => LiabilityAccount,
        ElementType::REVENUE => RevenueAccount, ElementType::EXPENSES => ExpenseAccount
      }.fetch(element_type).where(id: id).pick(:name)
    end

    def next_date(entry, today)
      sql = ActiveRecord::Base.sanitize_sql_array([
        "SELECT get_recurring_dates(?, ?, ?, ?, ?::DATE, ?::DATE, ?::DATE, ?::DATE) LIMIT 1",
        entry.interval_unit, entry.interval_count, entry.day_of_month, entry.weekday,
        entry.start_date, entry.end_date, today, today + NEXT_DATE_SEARCH_DAYS
      ])

      ActiveRecord::Base.connection.select_value(sql)&.to_date
    end
  end
end
