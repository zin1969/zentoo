# frozen_string_literal: true

module RecurringEntries
  # 決まった支払いの回: 未登録の回の一覧、確かめてからの登録、飛ばす
  class OccurrencesService
    class NotFound < StandardError; end
    class NotScheduled < StandardError; end
    class AlreadyRecorded < StandardError; end
    class AccountNotFound < StandardError; end

    Item = Struct.new(:entry, :scheduled_date, :debit_account_name, :credit_account_name, keyword_init: true)

    KIND_EXPENSE = 1
    KIND_INCOME = 2
    KIND_TRANSFER = 3

    def initialize(
      journal_entries: Journals::InsertJournalEntry.new,
      income_journals: Journals::IncomeJournals.new,
      transfer_journals: Journals::TransferJournals.new
    )
      @journal_entries = journal_entries
      @income_journals = income_journals
      @transfer_journals = transfer_journals
    end

    # 今月の末日までの、まだ登録も飛ばしもしていない回（先月以前の取り残しも含む）。予定日の順
    #
    # @return [Array<Item>]
    def pending(user:, today: Date.current)
      rows = ActiveRecord::Base.connection.select_rows(
        ActiveRecord::Base.sanitize_sql_array([
          "SELECT recurring_entry_id, scheduled_date FROM get_pending_recurring_dates(?, ?::DATE)",
          user.id, today.end_of_month
        ])
      )
      entries = user.recurring_entries.where(id: rows.map(&:first)).index_by(&:id)
      names = RecurringEntriesService.new

      rows.map do |entry_id, scheduled_date|
        entry = entries.fetch(entry_id.to_i)

        Item.new(
          entry: entry, scheduled_date: scheduled_date.to_date,
          debit_account_name: names.debit_account_name(entry), credit_account_name: names.credit_account_name(entry)
        )
      end
    end

    # 回を仕訳にする。金額は確かめた（直した）もの、日付は省略すると予定日
    #
    # @return [Integer] 登録した仕訳の ID
    def register!(user:, id:, scheduled_date:, amount:, date: nil)
      record!(user, id, scheduled_date) do |entry|
        journal_id = create_journal!(user, entry, date || scheduled_date, amount)
        { journal_id: journal_id }
      end
    end

    # 回を飛ばす（「今回はなし」）
    def skip!(user:, id:, scheduled_date:)
      record!(user, id, scheduled_date) { { skipped: true } }
    end

    private

    # 同じ回を同時に登録しないよう、決まった支払いの行をロックしてから確かめる
    def record!(user, id, scheduled_date)
      RecurringEntry.transaction do
        entry = user.recurring_entries.lock.find_by(id: id) || raise(NotFound)
        raise NotScheduled unless scheduled?(entry, scheduled_date)
        raise AlreadyRecorded if entry.recurring_entry_occurrences.exists?(scheduled_date: scheduled_date)

        attributes = yield(entry)
        entry.recurring_entry_occurrences.create!(scheduled_date: scheduled_date, **attributes)
        attributes[:journal_id]
      end
    end

    def scheduled?(entry, date)
      value = ActiveRecord::Base.connection.select_value(
        ActiveRecord::Base.sanitize_sql_array([
          "SELECT EXISTS (SELECT 1 FROM get_recurring_dates(?, ?, ?, ?, ?::DATE, ?::DATE, ?::DATE, ?::DATE))",
          entry.interval_unit, entry.interval_count, entry.day_of_month, entry.weekday,
          entry.start_date, entry.end_date, date, date
        ])
      )
      ActiveModel::Type::Boolean.new.cast(value)
    end

    # 支出はお買い物、収入は収入登録、振替は振替と同じ処理で登録する
    # （科目の確認やカードの引き落とし仕訳もそちらで行う）
    def create_journal!(user, entry, date, amount)
      description = entry.store_name.presence || entry.name

      case entry.kind
      when KIND_EXPENSE
        @journal_entries.insert_journal_entry!(journal_data: expense_journal(user, entry, date, amount))
      when KIND_INCOME
        @income_journals.create!(
          journal_date: date, asset_account_id: entry.debit_account_id, revenue_account_id: entry.credit_account_id,
          amount: amount, description: description, user_id: user.id
        )
      when KIND_TRANSFER
        @transfer_journals.create!(
          journal_date: date, from_element_type: entry.credit_element_type, from_account_id: entry.credit_account_id,
          to_account_id: entry.debit_account_id, amount: amount, description: description, user_id: user.id
        )
      end
    end

    def expense_journal(user, entry, date, amount)
      {
        date: date, user_id: user.id, store_name: entry.store_name,
        debits: [
          { element_type: ElementType::EXPENSES, account_id: entry.debit_account_id, amount: amount,
            item_name: entry.item_name.presence || entry.name }
        ],
        credits: [
          { element_type: entry.credit_element_type, payment_method_type: payment_method_type(entry),
            account_id: entry.credit_account_id, amount: amount }
        ]
      }
    end

    # 支払い方法の種類は、口座・カードの種類と同じ値。口座・カードが見つからなければ登録しない
    def payment_method_type(entry)
      if entry.credit_element_type == ElementType::ASSETS
        account = AssetAccount.find_by(id: entry.credit_account_id, user_id: entry.user_id) || raise(AccountNotFound)
        AssetAccount.asset_types.fetch(account.asset_type)
      else
        account = LiabilityAccount.find_by(id: entry.credit_account_id, user_id: entry.user_id) || raise(AccountNotFound)
        LiabilityAccount.liability_types.fetch(account.liability_type)
      end
    end
  end
end
