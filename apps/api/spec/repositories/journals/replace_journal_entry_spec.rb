# frozen_string_literal: true

require "rails_helper"

RSpec.describe Journals::ReplaceJournalEntry do
  subject(:repository) { described_class.new }

  let(:user) { create(:user, :masa) }
  let!(:eating_out) { create(:expense_account, :eating_out, :common) }
  let!(:movie) { create(:expense_account, :movie, :common) }
  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:tcard) { create(:liability_account, :tcard, user: user) }

  before { create(:credit_card, :tcard, user: user, liability_account: tcard, bank_account: bank) }

  def cash_payment(account = cash)
    { element_type: 1, payment_method_type: 1, account_id: account.id }
  end

  def card_payment
    { element_type: 2, payment_method_type: 3, account_id: tcard.id }
  end

  def entry(credit:, owner: user, date: "2025-11-09", store_name: "Aquavit 001", expense: eating_out, item_name: "バー",
            amount: 3_300)
    {
      date: date,
      user_id: owner.id,
      store_name: store_name,
      debits: [ { element_type: 5, account_id: expense.id, item_name: item_name, amount: amount } ],
      credits: [ credit.merge(amount: amount) ]
    }
  end

  def register(**options)
    Journals::InsertJournalEntry.new.insert_journal_entry!(journal_data: entry(**options))
  end

  # DB 関数の RAISE でテスト全体のトランザクションが中断されないよう、savepoint の中で呼ぶ
  def replace(journal_id, journal_data)
    ActiveRecord::Base.transaction(requires_new: true) do
      repository.replace_journal_entry!(journal_id: journal_id, journal_data: journal_data)
    end
  end

  it "replaces the journal with the new content under a new id" do
    journal_id = register(credit: cash_payment)

    new_id = replace(journal_id, entry(credit: cash_payment, date: "2025-11-10", store_name: "TOHO シネマズ",
                                       expense: movie, item_name: "映画", amount: 2_000))

    expect(new_id).not_to eq(journal_id)
    expect(Journal.exists?(journal_id)).to be(false)

    journal = Journal.find(new_id)
    expect([ journal.journal_dt, journal.store_name, journal.user_id ]).to eq([ Date.new(2025, 11, 10), "TOHO シネマズ", user.id ])
    expect(journal.debits.map { |d| [ d.account_id, d.item_name, d.amount.to_i ] }).to eq([ [ movie.id, "映画", 2_000 ] ])
    expect(journal.credits.map { |c| [ c.account_id, c.amount.to_i ] }).to eq([ [ cash.id, 2_000 ] ])
  end

  it "recreates the direct debit journal when the card payment changes" do
    journal_id = register(credit: card_payment)
    old_direct_debit_id = DirectDebitJournal.find_by!(original_id: journal_id).direct_debit_id

    new_id = replace(journal_id, entry(credit: card_payment, amount: 5_000))

    expect(Journal.exists?(old_direct_debit_id)).to be(false)
    direct_debit = Journal.find(DirectDebitJournal.find_by!(original_id: new_id).direct_debit_id)
    expect(direct_debit.credits.sole.amount.to_i).to eq(5_000)
    expect(DirectDebitJournal.count).to eq(1)
  end

  it "removes the direct debit journal when a card payment becomes a cash payment" do
    journal_id = register(credit: card_payment)

    new_id = replace(journal_id, entry(credit: cash_payment))

    expect(DirectDebitJournal.count).to eq(0)
    expect(Journal.pluck(:id)).to eq([ new_id ])
  end

  it "creates a direct debit journal when a cash payment becomes a card payment" do
    journal_id = register(credit: cash_payment)

    new_id = replace(journal_id, entry(credit: card_payment))

    expect(DirectDebitJournal.where(original_id: new_id).count).to eq(1)
  end

  describe "checks" do
    it "rejects another user's journal the same way as a missing one" do
      other = create(:user)
      other_cash = create(:asset_account, :cash, user: other)
      journal_id = register(credit: cash_payment(other_cash), owner: other)

      expect { replace(journal_id, entry(credit: cash_payment)) }.to raise_error(described_class::JournalNotFound)
      expect { replace(0, entry(credit: cash_payment)) }.to raise_error(described_class::JournalNotFound)
      expect(Journal.exists?(journal_id)).to be(true)
    end

    it "rejects a direct debit journal" do
      journal_id = register(credit: card_payment)
      direct_debit_id = DirectDebitJournal.find_by!(original_id: journal_id).direct_debit_id

      expect { replace(direct_debit_id, entry(credit: cash_payment)) }
        .to raise_error(described_class::DirectDebitJournalNotEditable)
    end

    it "rejects a journal that is not a shopping journal" do
      deposit_id = Journals::CreateCashDeposit.new.create_cash_deposit!(
        journal_date: Date.new(2025, 12, 9), bank_account_id: bank.id, amount: 45_000, user_id: user.id
      )

      expect { replace(deposit_id, entry(credit: cash_payment)) }.to raise_error(described_class::JournalNotEditable)
      expect(Journal.exists?(deposit_id)).to be(true)
    end

    it "rejects new content that debits something other than expenses" do
      journal_id = register(credit: cash_payment)
      data = entry(credit: cash_payment)
      data[:debits] = [ { element_type: 1, account_id: bank.id, item_name: "預入", amount: 3_300 } ]

      expect { replace(journal_id, data) }.to raise_error(described_class::ExpenseDebitsRequired)
      expect(Journal.exists?(journal_id)).to be(true)
    end

    it "keeps the original journal when the new content is unbalanced" do
      journal_id = register(credit: card_payment)
      data = entry(credit: cash_payment)
      data[:credits].first[:amount] = 1

      expect { replace(journal_id, data) }.to raise_error(Journals::InsertJournalEntry::UnbalancedJournal)
      expect(Journal.exists?(journal_id)).to be(true)
      expect(DirectDebitJournal.where(original_id: journal_id).count).to eq(1)
    end

    it "keeps the original journal when the new content uses another user's account" do
      journal_id = register(credit: cash_payment)
      other_cash = create(:asset_account, :cash, user: create(:user))

      expect { replace(journal_id, entry(credit: cash_payment(other_cash))) }
        .to raise_error(Journals::InsertJournalEntry::AccountNotFound)
      expect(Journal.exists?(journal_id)).to be(true)
    end
  end

  describe "a direct debit date changed by hand" do
    let!(:journal_id) { register(credit: card_payment) }

    def direct_debit_of(id)
      link = DirectDebitJournal.find_by!(original_id: id)
      [ Journal.find(link.direct_debit_id), link ]
    end

    before do
      direct_debit, = direct_debit_of(journal_id)
      Journals::UpdateDirectDebitDate.new.update_direct_debit_date!(
        journal_id: direct_debit.id, payment_date: Date.new(2025, 12, 27), user_id: user.id
      )
    end

    it "is kept when the journal is still paid by the same card" do
      new_id = replace(journal_id, entry(credit: card_payment, amount: 5_000))

      direct_debit, link = direct_debit_of(new_id)
      expect(direct_debit.journal_dt).to eq(Date.new(2025, 12, 27))
      expect(direct_debit.credits.sole.amount.to_i).to eq(5_000)
      expect(link.payment_date_overridden).to be(true)
    end

    it "is recalculated when the purchase date moves after it" do
      new_id = replace(journal_id, entry(credit: card_payment, date: "2025-12-28"))

      direct_debit, link = direct_debit_of(new_id)
      expect(direct_debit.journal_dt).to eq(Date.new(2026, 1, 27))
      expect(link.payment_date_overridden).to be(false)
    end

    it "is recalculated when the journal is paid by another card" do
      jal = create(:liability_account, :jal, user: user)
      create(:credit_card, :jal, user: user, liability_account: jal, bank_account: bank)

      new_id = replace(journal_id, entry(credit: { element_type: 2, payment_method_type: 3, account_id: jal.id }))

      direct_debit, link = direct_debit_of(new_id)
      expect(direct_debit.journal_dt).to eq(Date.new(2025, 12, 10))
      expect(link.payment_date_overridden).to be(false)
    end

    it "is dropped when the journal becomes a cash payment" do
      new_id = replace(journal_id, entry(credit: cash_payment))

      expect(DirectDebitJournal.where(original_id: new_id)).to be_empty
    end

    it "does not leak into a later journal in the same transaction" do
      replace(journal_id, entry(credit: card_payment))
      later_id = register(credit: card_payment)

      direct_debit, = direct_debit_of(later_id)
      expect(direct_debit.journal_dt).to eq(Date.new(2025, 11, 27))
    end
  end
end
