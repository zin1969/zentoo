# frozen_string_literal: true

require "rails_helper"

RSpec.describe Journals::IncomeJournals do
  subject(:repository) { described_class.new }

  let(:user) { create(:user, :masa) }
  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:salary) { create(:revenue_account, :salary, :common) }
  let!(:bonus) { create(:revenue_account, :bonus, :common) }

  def income(**overrides)
    {
      journal_date: Date.new(2026, 11, 25), asset_account_id: bank.id, revenue_account_id: salary.id,
      amount: 300_000, description: "ゼンギン株式会社", user_id: user.id
    }.merge(overrides)
  end

  # DB 関数の RAISE でテスト全体のトランザクションが中断されないよう、savepoint の中で呼ぶ
  def create_income(**overrides)
    ActiveRecord::Base.transaction(requires_new: true) { repository.create!(**income(**overrides)) }
  end

  def replace_income(journal_id, **overrides)
    ActiveRecord::Base.transaction(requires_new: true) { repository.replace!(journal_id: journal_id, **income(**overrides)) }
  end

  describe "#create!" do
    it "debits the account and credits the revenue account" do
      journal = Journal.find(create_income)

      expect([ journal.journal_dt, journal.store_name, journal.user_id ])
        .to eq([ Date.new(2026, 11, 25), "ゼンギン株式会社", user.id ])

      debit = journal.debits.sole
      expect([ debit.element_type.to_i, debit.account_id, debit.item_name, debit.amount.to_i ])
        .to eq([ 1, bank.id, nil, 300_000 ])

      credit = journal.credits.sole
      expect([ credit.element_type.to_i, credit.payment_method_type, credit.account_id, credit.amount.to_i ])
        .to eq([ 4, 0, salary.id, 300_000 ])
    end

    it "uses the revenue account name when the description is blank" do
      expect(Journal.find(create_income(description: "  ")).store_name).to eq("給与")
      expect(Journal.find(create_income(description: nil)).store_name).to eq("給与")
    end

    it "accepts any account of the user, including cash" do
      journal = Journal.find(create_income(asset_account_id: cash.id, amount: 5_000))

      expect(journal.debits.sole.account_id).to eq(cash.id)
    end

    it "increases the balance of the account" do
      create_income

      balance = Reports::AccountBalances.new.list(user_id: user.id, as_of: Date.new(2026, 11, 30))
                                       .find { |b| b.account_id == bank.id }.balance
      expect(balance).to eq(300_000)
    end

    it "rejects an amount of 0 or less" do
      expect { create_income(amount: 0) }.to raise_error(ActiveRecord::StatementInvalid, /amount must be greater than 0/)
    end

    it "rejects another user's account and a missing account the same way" do
      other_bank = create(:asset_account, :mufg_yoga, user: create(:user))

      expect { create_income(asset_account_id: other_bank.id) }.to raise_error(described_class::AssetAccountNotFound)
      expect { create_income(asset_account_id: 0) }.to raise_error(described_class::AssetAccountNotFound)
    end

    it "rejects another user's own revenue account and a missing one the same way" do
      other_revenue = create(:revenue_account, name: "other-user-revenue", user: create(:user))

      expect { create_income(revenue_account_id: other_revenue.id) }.to raise_error(described_class::RevenueAccountNotFound)
      expect { create_income(revenue_account_id: 0) }.to raise_error(described_class::RevenueAccountNotFound)
      expect(Journal.count).to eq(0)
    end
  end

  describe "#replace!" do
    let!(:journal_id) { create_income }

    it "replaces the income with the new content under a new id" do
      new_id = replace_income(journal_id, revenue_account_id: bonus.id, amount: 500_000, asset_account_id: cash.id,
                                          description: "")

      expect(new_id).not_to eq(journal_id)
      expect(Journal.exists?(journal_id)).to be(false)

      journal = Journal.find(new_id)
      expect(journal.store_name).to eq("賞与")
      debit = journal.debits.sole
      expect([ debit.account_id, debit.amount.to_i ]).to eq([ cash.id, 500_000 ])
      expect(journal.credits.sole.account_id).to eq(bonus.id)
    end

    it "keeps the original income when the new content is invalid" do
      expect { replace_income(journal_id, revenue_account_id: 0) }.to raise_error(described_class::RevenueAccountNotFound)
      expect(Journal.exists?(journal_id)).to be(true)
    end

    it "rejects a journal that is not an income journal" do
      deposit_id = Journals::CreateCashDeposit.new.create_cash_deposit!(
        journal_date: Date.new(2026, 11, 26), bank_account_id: bank.id, amount: 1_000, user_id: user.id
      )

      expect { replace_income(deposit_id) }.to raise_error(described_class::NotIncomeJournal)
      expect(Journal.exists?(deposit_id)).to be(true)
    end

    it "rejects another user's journal the same way as a missing one" do
      other = create(:user)

      expect { replace_income(journal_id, user_id: other.id) }.to raise_error(described_class::JournalNotFound)
      expect { replace_income(0) }.to raise_error(described_class::JournalNotFound)
    end
  end
end
