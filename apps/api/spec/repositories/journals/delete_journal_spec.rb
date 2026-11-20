# frozen_string_literal: true

require "rails_helper"

RSpec.describe Journals::DeleteJournal do
  subject(:repository) { described_class.new }

  let(:user) { create(:user, :masa) }
  let!(:expense) { create(:expense_account, :eating_out, :common) }
  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:tcard) { create(:liability_account, :tcard, user: user) }

  before { create(:credit_card, :tcard, user: user, liability_account: tcard, bank_account: bank) }

  def register(credit:, owner: user, date: "2025-11-09")
    Journals::InsertJournalEntry.new.insert_journal_entry!(
      journal_data: {
        date: date,
        user_id: owner.id,
        store_name: "Aquavit 001",
        debits: [ { element_type: 5, account_id: expense.id, item_name: "バー", amount: 3_300 } ],
        credits: [ credit.merge(amount: 3_300) ]
      }
    )
  end

  def cash_payment(account = cash)
    { element_type: 1, payment_method_type: 1, account_id: account.id }
  end

  def card_payment
    { element_type: 2, payment_method_type: 3, account_id: tcard.id }
  end

  # DB 関数の RAISE でテスト全体のトランザクションが中断されないよう、savepoint の中で呼ぶ
  def delete(journal_id, owner: user)
    ActiveRecord::Base.transaction(requires_new: true) do
      repository.delete!(journal_id: journal_id, user_id: owner.id)
    end
  end

  it "deletes a journal with its debits and credits" do
    journal_id = register(credit: cash_payment)

    expect(delete(journal_id)).to eq(1)
    expect(Journal.exists?(journal_id)).to be(false)
    expect(Debit.where(journal_id: journal_id)).to be_empty
    expect(Credit.where(journal_id: journal_id)).to be_empty
  end

  it "does not touch other journals" do
    journal_id = register(credit: cash_payment)
    other_id = register(credit: cash_payment)

    delete(journal_id)

    expect(Journal.find(other_id).debits.count).to eq(1)
    expect(Journal.find(other_id).credits.count).to eq(1)
  end

  context "when the journal was paid by credit card" do
    let!(:journal_id) { register(credit: card_payment) }
    let!(:direct_debit_id) { DirectDebitJournal.find_by!(original_id: journal_id).direct_debit_id }

    it "also deletes the direct debit journal created for it" do
      expect(delete(journal_id)).to eq(2)
      expect(Journal.where(id: [ journal_id, direct_debit_id ])).to be_empty
      expect(DirectDebitJournal.count).to eq(0)
      expect(Debit.count + Credit.count).to eq(0)
    end

    it "refuses to delete the direct debit journal on its own" do
      expect { delete(direct_debit_id) }.to raise_error(described_class::DirectDebitJournalNotDeletable)
      expect(Journal.count).to eq(2)
      expect(DirectDebitJournal.count).to eq(1)
    end
  end

  it "deletes an opening liability with its direct debit journal" do
    create(:equity_account, :original_deposit, :common)
    journal_id = Journals::CreateOpeningLiability.new.create_opening_liability_balance!(
      journal_date: Date.new(2026, 10, 30),
      liability_account_id: tcard.id,
      amount: 30_000,
      payment_date: Date.new(2026, 11, 28),
      user_id: user.id
    )

    expect(delete(journal_id)).to eq(2)
    expect(Journal.count).to eq(0)
    expect(DirectDebitJournal.count).to eq(0)
  end

  describe "owner check" do
    it "rejects another user's journal the same way as a missing one" do
      other = create(:user)
      other_cash = create(:asset_account, :cash, user: other)
      journal_id = register(credit: cash_payment(other_cash), owner: other)

      expect { delete(journal_id) }.to raise_error(described_class::JournalNotFound)
      expect { delete(0) }.to raise_error(described_class::JournalNotFound)
      expect(Journal.exists?(journal_id)).to be(true)
    end
  end
end
