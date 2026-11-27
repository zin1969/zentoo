# frozen_string_literal: true

require "rails_helper"

# 決まった支払いのテーブルの制約と、回の記録（登録した仕訳・飛ばした回）
RSpec.describe "recurring_entries" do
  let(:user) { create(:user, :masa) }
  let!(:food) { create(:expense_account, :food, :common) }
  let!(:salary) { create(:revenue_account, :salary, :common) }
  let!(:cash) { create(:asset_account, :cash, user: user) }

  let(:entry) { create(:recurring_entry, user: user, debit_account_id: food.id, credit_account_id: cash.id) }

  # DB の制約違反でテスト全体のトランザクションが中断されないよう、savepoint の中で作る
  def create_entry(**attributes)
    ActiveRecord::Base.transaction(requires_new: true) do
      create(:recurring_entry, user: user, debit_account_id: food.id, credit_account_id: cash.id, **attributes)
    end
  end

  def spend(amount: 85_000)
    Journals::InsertJournalEntry.new.insert_journal_entry!(
      journal_data: {
        date: "2026-11-27", user_id: user.id, store_name: "大家",
        debits: [ { element_type: 5, account_id: food.id, amount: amount, item_name: "家賃" } ],
        credits: [ { element_type: 1, payment_method_type: 1, account_id: cash.id, amount: amount } ]
      }
    )
  end

  describe "check constraints" do
    it "accepts a monthly and a weekly schedule" do
      expect { create_entry }.not_to raise_error
      expect { create_entry(interval_unit: 2, day_of_month: nil, weekday: 5) }.not_to raise_error
    end

    it "accepts a transfer from an asset or a liability" do
      expect { create_entry(kind: 3, debit_account_id: cash.id, credit_element_type: 1) }.not_to raise_error
      expect { create_entry(kind: 3, debit_account_id: cash.id, credit_element_type: 2) }.not_to raise_error
    end

    it "rejects a schedule that does not match its unit" do
      expect { create_entry(day_of_month: 32) }.to raise_error(ActiveRecord::StatementInvalid, /recurring_entry_schedule/)
      expect { create_entry(weekday: 1) }.to raise_error(ActiveRecord::StatementInvalid, /recurring_entry_schedule/)
      expect { create_entry(interval_unit: 2, day_of_month: nil, weekday: 7) }
        .to raise_error(ActiveRecord::StatementInvalid, /recurring_entry_schedule/)
      expect { create_entry(interval_count: 13) }
        .to raise_error(ActiveRecord::StatementInvalid, /recurring_entry_interval_count/)
    end

    it "rejects a payment method that does not match the kind, a zero amount, and an end before the start" do
      expect { create_entry(credit_element_type: 4) }
        .to raise_error(ActiveRecord::StatementInvalid, /recurring_entry_credit_element_type/)
      expect { create_entry(kind: 2, credit_element_type: 1) }
        .to raise_error(ActiveRecord::StatementInvalid, /recurring_entry_credit_element_type/)
      expect { create_entry(kind: 3, credit_element_type: 4) }
        .to raise_error(ActiveRecord::StatementInvalid, /recurring_entry_credit_element_type/)
      # 種類が 1〜3 でなければ、種類と貸方の種別のどちらかの制約で落ちる（どちらが先に報告されるかは決まっていない）
      expect { create_entry(kind: 4) }
        .to raise_error(ActiveRecord::StatementInvalid, /recurring_entry_(kind|credit_element_type)/)
      expect { create_entry(amount: 0) }.to raise_error(ActiveRecord::StatementInvalid, /recurring_entry_amount/)
      expect { create_entry(end_date: Date.new(2026, 10, 31)) }
        .to raise_error(ActiveRecord::StatementInvalid, /recurring_entry_period/)
    end
  end

  describe "occurrences" do
    def add_occurrence(**attributes)
      ActiveRecord::Base.transaction(requires_new: true) do
        RecurringEntryOccurrence.create!(recurring_entry: entry, scheduled_date: Date.new(2026, 11, 27), **attributes)
      end
    end

    it "holds either the journal or the skip, once per date" do
      expect { add_occurrence }.to raise_error(ActiveRecord::StatementInvalid, /journal_or_skipped/)
      expect { add_occurrence(journal_id: spend, skipped: true) }
        .to raise_error(ActiveRecord::StatementInvalid, /journal_or_skipped/)

      add_occurrence(skipped: true)
      expect { add_occurrence(journal_id: spend) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "goes back to unregistered when the journal is deleted, and goes away with the entry" do
      journal_id = spend
      add_occurrence(journal_id: journal_id)

      ActiveRecord::Base.connection.execute("SELECT delete_journal(#{journal_id}, #{user.id})")
      expect(RecurringEntryOccurrence.count).to eq(0)

      add_occurrence(skipped: true)
      entry.destroy!
      expect(RecurringEntryOccurrence.count).to eq(0)
    end
  end

  describe "editing a journal registered from an entry" do
    it "keeps the occurrence on the new journal of a purchase" do
      journal_id = spend
      RecurringEntryOccurrence.create!(recurring_entry: entry, scheduled_date: Date.new(2026, 11, 27), journal_id: journal_id)

      new_id = Journals::ReplaceJournalEntry.new.replace_journal_entry!(
        journal_id: journal_id,
        journal_data: {
          date: "2026-11-27", user_id: user.id, store_name: "大家",
          debits: [ { element_type: 5, account_id: food.id, amount: 86_000, item_name: "家賃" } ],
          credits: [ { element_type: 1, payment_method_type: 1, account_id: cash.id, amount: 86_000 } ]
        }
      )

      expect(RecurringEntryOccurrence.pluck(:recurring_entry_id, :scheduled_date, :journal_id))
        .to eq([ [ entry.id, Date.new(2026, 11, 27), new_id ] ])
    end

    it "keeps the occurrence on the new journal of an income" do
      income = create(:recurring_entry, user: user, kind: 2, name: "給料", day_of_month: 25,
                                        debit_account_id: cash.id, credit_element_type: 4, credit_account_id: salary.id)
      repository = Journals::IncomeJournals.new
      journal_id = repository.create!(journal_date: Date.new(2026, 11, 25), asset_account_id: cash.id,
                                      revenue_account_id: salary.id, amount: 250_000, description: "11 月分", user_id: user.id)
      RecurringEntryOccurrence.create!(recurring_entry: income, scheduled_date: Date.new(2026, 11, 25), journal_id: journal_id)

      new_id = repository.replace!(journal_id: journal_id, journal_date: Date.new(2026, 11, 25), asset_account_id: cash.id,
                                   revenue_account_id: salary.id, amount: 260_000, description: "11 月分", user_id: user.id)

      expect(RecurringEntryOccurrence.pluck(:recurring_entry_id, :journal_id)).to eq([ [ income.id, new_id ] ])
    end
  end
end
