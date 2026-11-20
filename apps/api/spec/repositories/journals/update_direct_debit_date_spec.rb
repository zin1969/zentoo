# frozen_string_literal: true

require "rails_helper"

RSpec.describe Journals::UpdateDirectDebitDate do
  subject(:repository) { described_class.new }

  let(:user) { create(:user, :masa) }
  let!(:expense) { create(:expense_account, :eating_out, :common) }
  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:tcard) { create(:liability_account, :tcard, user: user) }

  before { create(:credit_card, :tcard, user: user, liability_account: tcard, bank_account: bank) }

  def register(credit:, owner: user)
    Journals::InsertJournalEntry.new.insert_journal_entry!(
      journal_data: {
        date: "2025-11-09",
        user_id: owner.id,
        store_name: "Aquavit 001",
        debits: [ { element_type: 5, account_id: expense.id, item_name: "バー", amount: 3_300 } ],
        credits: [ credit.merge(amount: 3_300) ]
      }
    )
  end

  def card_payment
    { element_type: 2, payment_method_type: 3, account_id: tcard.id }
  end

  # DB 関数の RAISE でテスト全体のトランザクションが中断されないよう、savepoint の中で呼ぶ
  def update(journal_id, payment_date, owner: user)
    ActiveRecord::Base.transaction(requires_new: true) do
      repository.update_direct_debit_date!(journal_id: journal_id, payment_date: payment_date, user_id: owner.id)
    end
  end

  context "with a card payment" do
    let!(:journal_id) { register(credit: card_payment) }
    let(:link) { DirectDebitJournal.find_by!(original_id: journal_id) }
    let(:direct_debit) { Journal.find(link.direct_debit_id) }

    it "changes only the date of the direct debit journal and marks it as overridden" do
      expect(direct_debit.journal_dt).to eq(Date.new(2025, 11, 27))
      expect(link.payment_date_overridden).to be(false)

      expect(update(direct_debit.id, Date.new(2025, 12, 27))).to eq(direct_debit.id)

      expect(direct_debit.reload.journal_dt).to eq(Date.new(2025, 12, 27))
      expect(link.reload.payment_date_overridden).to be(true)
      expect(direct_debit.debits.sole.amount.to_i).to eq(3_300)
      expect(direct_debit.credits.sole.account_id).to eq(bank.id)
      expect(Journal.find(journal_id).journal_dt).to eq(Date.new(2025, 11, 9))
    end

    it "keeps a weekend date as it is" do
      update(direct_debit.id, Date.new(2025, 12, 28))

      expect(direct_debit.reload.journal_dt).to eq(Date.new(2025, 12, 28))
    end

    it "accepts the purchase date but rejects a date before it" do
      expect(update(direct_debit.id, Date.new(2025, 11, 9))).to eq(direct_debit.id)

      expect { update(direct_debit.id, Date.new(2025, 11, 8)) }
        .to raise_error(described_class::PaymentDateBeforeJournalDate)
      expect(direct_debit.reload.journal_dt).to eq(Date.new(2025, 11, 9))
    end

    it "rejects the original card payment journal" do
      expect { update(journal_id, Date.new(2025, 12, 27)) }.to raise_error(described_class::NotDirectDebitJournal)
    end

    it "rejects another user's journal the same way as a missing one" do
      other = create(:user)

      expect { update(direct_debit.id, Date.new(2025, 12, 27), owner: other) }
        .to raise_error(described_class::JournalNotFound)
      expect { update(0, Date.new(2025, 12, 27)) }.to raise_error(described_class::JournalNotFound)
      expect(direct_debit.reload.journal_dt).to eq(Date.new(2025, 11, 27))
    end
  end

  it "rejects a cash payment journal" do
    journal_id = register(credit: { element_type: 1, payment_method_type: 1, account_id: cash.id })

    expect { update(journal_id, Date.new(2025, 12, 27)) }.to raise_error(described_class::NotDirectDebitJournal)
  end

  it "changes the direct debit date of an opening liability, not before the opening date" do
    create(:equity_account, :original_deposit, :common)
    journal_id = Journals::CreateOpeningLiability.new.create_opening_liability_balance!(
      journal_date: Date.new(2026, 10, 30), liability_account_id: tcard.id, amount: 30_000,
      payment_date: Date.new(2026, 11, 28), user_id: user.id
    )
    direct_debit_id = DirectDebitJournal.find_by!(original_id: journal_id).direct_debit_id

    update(direct_debit_id, Date.new(2026, 12, 28))

    expect(Journal.find(direct_debit_id).journal_dt).to eq(Date.new(2026, 12, 28))
    expect { update(direct_debit_id, Date.new(2026, 10, 29)) }
      .to raise_error(described_class::PaymentDateBeforeJournalDate)
  end
end
