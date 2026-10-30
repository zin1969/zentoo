# frozen_string_literal: true

require "rails_helper"

RSpec.describe Journals::CreateOpeningLiability do
  subject(:repository) { described_class.new }

  let(:user) { create(:user, :masa) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:tcard) { create(:liability_account, :tcard, user: user) }
  let!(:equity) { create(:equity_account, :original_deposit, :common) }

  before { create(:credit_card, :tcard, user: user, liability_account: tcard, bank_account: bank) }

  # DB 関数の RAISE でテスト全体のトランザクションが中断されないよう、savepoint の中で呼ぶ
  def create_opening(liability_account_id: tcard.id, journal_date: Date.new(2026, 10, 30), payment_date: Date.new(2026, 11, 28),
                     amount: 30_000, owner: user)
    ActiveRecord::Base.transaction(requires_new: true) do
      repository.create_opening_liability_balance!(
        journal_date: journal_date,
        liability_account_id: liability_account_id,
        amount: amount,
        payment_date: payment_date,
        user_id: owner.id
      )
    end
  end

  describe "the opening journal" do
    let(:journal) { Journal.find(create_opening) }

    it "debits the equity account and credits the card" do
      expect(journal.journal_dt).to eq(Date.new(2026, 10, 30))
      expect(journal.store_name).to eq("tcard")
      expect(journal.user_id).to eq(user.id)

      debit = journal.debits.sole
      expect([ debit.element_type.to_i, debit.account_id, debit.item_name, debit.amount.to_i, debit.user_id ])
        .to eq([ 3, equity.id, "開始残高", 30_000, user.id ])

      credit = journal.credits.sole
      expect([ credit.element_type.to_i, credit.payment_method_type, credit.account_id, credit.amount.to_i, credit.user_id ])
        .to eq([ 2, 3, tcard.id, 30_000, user.id ])
    end
  end

  describe "the direct debit journal" do
    let!(:journal_id) { create_opening }
    let(:link) { DirectDebitJournal.find_by!(original_id: journal_id) }
    let(:debit_journal) { Journal.find(link.direct_debit_id) }

    it "is created once, on the given payment date without moving it to a business day" do
      # 2026-11-28 は土曜日。指定された日付をそのまま使う
      expect(Journal.count).to eq(2)
      expect(DirectDebitJournal.count).to eq(1)
      expect(debit_journal.journal_dt).to eq(Date.new(2026, 11, 28))
      expect(debit_journal.user_id).to eq(user.id)
    end

    it "debits the card and credits the bank account" do
      debit = debit_journal.debits.sole
      expect([ debit.element_type.to_i, debit.account_id, debit.item_name, debit.amount.to_i ])
        .to eq([ 2, tcard.id, "開始残高", 30_000 ])

      credit = debit_journal.credits.sole
      expect([ credit.element_type.to_i, credit.payment_method_type, credit.account_id, credit.amount.to_i ])
        .to eq([ 1, 2, bank.id, 30_000 ])
    end
  end

  it "does not affect the payment date of later card payments in the same transaction" do
    create_opening

    purchase_id = Journals::InsertJournalEntry.new.insert_journal_entry!(
      journal_data: {
        date: "2026-10-20",
        user_id: user.id,
        store_name: "店",
        debits: [ { element_type: 5, account_id: create(:expense_account, :food, :common).id, amount: 1_000, item_name: "品" } ],
        credits: [ { element_type: 2, payment_method_type: 3, account_id: tcard.id, amount: 1_000 } ]
      }
    )

    # tcard は 10 日締め・27 日払い。10/20 の利用は 11/27（金）に引き落とされる
    debit_journal = Journal.find(DirectDebitJournal.find_by!(original_id: purchase_id).direct_debit_id)
    expect(debit_journal.journal_dt).to eq(Date.new(2026, 11, 27))
  end

  describe "payment date" do
    it "accepts the same day as the journal date" do
      expect { create_opening(payment_date: Date.new(2026, 10, 30)) }.not_to raise_error
    end

    it "rejects a payment date before the journal date" do
      expect do
        expect { create_opening(payment_date: Date.new(2026, 10, 29)) }.to raise_error(described_class::PaymentDateBeforeJournalDate)
      end.not_to change(Journal, :count)
    end
  end

  describe "duplicate check" do
    it "rejects the same card with the same payment date" do
      create_opening

      expect do
        expect { create_opening(amount: 5_000) }.to raise_error(described_class::OpeningLiabilityAlreadyExists)
      end.not_to change(Journal, :count)
    end

    it "allows the same card with another payment date" do
      create_opening

      expect { create_opening(payment_date: Date.new(2026, 12, 27)) }.not_to raise_error
    end

    it "allows another card with the same payment date" do
      create_opening
      jal = create(:liability_account, :jal, user: user)
      create(:credit_card, :jal, user: user, liability_account: jal, bank_account: bank)

      expect { create_opening(liability_account_id: jal.id) }.not_to raise_error
    end
  end

  describe "card check" do
    it "rejects another user's card the same way as a missing one" do
      other_card = create(:liability_account, :jal, user: create(:user))

      expect { create_opening(liability_account_id: other_card.id) }.to raise_error(described_class::LiabilityAccountNotFound)
      expect { create_opening(liability_account_id: 0) }.to raise_error(described_class::LiabilityAccountNotFound)
    end

    it "rejects a liability that is not a credit card" do
      loan = create(:liability_account, user: user, liability_type: :loan)

      expect { create_opening(liability_account_id: loan.id) }.to raise_error(described_class::LiabilityAccountNotFound)
    end

    it "raises when the card has no setting, and creates nothing" do
      card_without_setting = create(:liability_account, :paypay, user: user)

      expect do
        expect { create_opening(liability_account_id: card_without_setting.id) }
          .to raise_error(described_class::CreditCardSettingNotFound)
      end.not_to change(Journal, :count)
    end
  end

  it "rejects an amount of 0 or less" do
    expect { create_opening(amount: 0) }.to raise_error(ActiveRecord::StatementInvalid, /amount must be greater than 0/)
  end
end
