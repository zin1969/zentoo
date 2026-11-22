# frozen_string_literal: true

require "rails_helper"

RSpec.describe Journals::TransferJournals do
  subject(:repository) { described_class.new }

  let(:user) { create(:user, :masa) }
  let!(:food) { create(:expense_account, :food, :common) }
  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:mizuho) { create(:asset_account, :mizuho_tamagawa, user: user) }
  let!(:suica) { create(:asset_account, :suica, user: user) }
  let!(:tcard) { create(:liability_account, :tcard, user: user) }

  # tcard は 10 日締め・27 日払い、引き落とし口座は三菱UFJ
  before { create(:credit_card, :tcard, user: user, liability_account: tcard, bank_account: bank) }

  def transfer_params(from:, to:, **overrides)
    {
      journal_date: Date.new(2026, 11, 5),
      from_element_type: from.is_a?(LiabilityAccount) ? ElementType::LIABILITIES : ElementType::ASSETS,
      from_account_id: from.id, to_account_id: to.id, amount: 10_000, description: nil, user_id: user.id
    }.merge(overrides)
  end

  # DB 関数の RAISE でテスト全体のトランザクションが中断されないよう、savepoint の中で呼ぶ
  def transfer(from:, to:, **overrides)
    ActiveRecord::Base.transaction(requires_new: true) { repository.create!(**transfer_params(from: from, to: to, **overrides)) }
  end

  def replace(journal_id, from:, to:, **overrides)
    ActiveRecord::Base.transaction(requires_new: true) do
      repository.replace!(journal_id: journal_id, **transfer_params(from: from, to: to, **overrides))
    end
  end

  def lines(journal_id)
    journal = Journal.find(journal_id)
    debit = journal.debits.sole
    credit = journal.credits.sole

    [ journal.store_name,
      [ debit.element_type.to_i, debit.account_id, debit.amount.to_i ],
      [ credit.element_type.to_i, credit.payment_method_type, credit.account_id, credit.amount.to_i ] ]
  end

  describe "#create!" do
    it "withdraws cash from a deposit account" do
      expect(lines(transfer(from: bank, to: cash))).to eq([ "引き出し", [ 1, cash.id, 10_000 ], [ 1, 2, bank.id, 10_000 ] ])
    end

    it "deposits cash into a deposit account" do
      expect(lines(transfer(from: cash, to: bank))).to eq([ "預入", [ 1, bank.id, 10_000 ], [ 1, 1, cash.id, 10_000 ] ])
    end

    it "transfers between deposit accounts" do
      expect(lines(transfer(from: bank, to: mizuho))).to eq([ "振替", [ 1, mizuho.id, 10_000 ], [ 1, 2, bank.id, 10_000 ] ])
    end

    it "charges e-money from cash or a deposit account" do
      expect(lines(transfer(from: cash, to: suica)).first).to eq("チャージ")
      expect(lines(transfer(from: bank, to: suica)).first).to eq("チャージ")
    end

    it "uses the description when given" do
      expect(lines(transfer(from: bank, to: mizuho, description: " 家賃用 ")).first).to eq("家賃用")
    end

    context "when charging e-money with a credit card" do
      let!(:journal_id) { transfer(from: tcard, to: suica) }

      it "credits the card and creates the direct debit journal" do
        expect(lines(journal_id)).to eq([ "チャージ", [ 1, suica.id, 10_000 ], [ 2, 3, tcard.id, 10_000 ] ])

        direct_debit = Journal.find(DirectDebitJournal.find_by!(original_id: journal_id).direct_debit_id)
        expect(direct_debit.journal_dt).to eq(Date.new(2026, 11, 27))
        expect(direct_debit.credits.sole.account_id).to eq(bank.id)
      end

      it "shows up as a scheduled withdrawal in the bank account ledger" do
        rows = Reports::BankAccountLedger.new.list(
          user_id: user.id, asset_account_id: bank.id, from: Date.new(2026, 11, 1), to: Date.new(2026, 11, 30)
        )

        expect(rows.last.to_h.slice(:row_type, :entry_date, :description, :withdrawal))
          .to eq(row_type: "card_payment", entry_date: Date.new(2026, 11, 27), description: "tcard", withdrawal: 10_000)
      end
    end

    it "rejects a card charge to something other than e-money" do
      expect { transfer(from: tcard, to: bank) }.to raise_error(described_class::CreditCardChargeRequiresEMoney)
      expect(Journal.count).to eq(0)
    end

    it "rejects a card without a direct debit setting" do
      paypay = create(:liability_account, :paypay, user: user)

      expect { transfer(from: paypay, to: suica) }.to raise_error(described_class::CreditCardSettingNotFound)
    end

    it "rejects the same account on both sides" do
      expect { transfer(from: bank, to: bank) }.to raise_error(described_class::SameAccount)
    end

    it "rejects another user's accounts the same way as missing ones" do
      other = create(:user)
      other_bank = create(:asset_account, :mufg_yoga, user: other)
      other_card = create(:liability_account, :jal, user: other)
      loan = create(:liability_account, user: user, liability_type: :loan, name: "住宅ローン")

      expect { transfer(from: other_bank, to: cash) }.to raise_error(described_class::FromAccountNotFound)
      expect { transfer(from: other_card, to: suica) }.to raise_error(described_class::FromAccountNotFound)
      expect { transfer(from: loan, to: suica) }.to raise_error(described_class::FromAccountNotFound)
      expect { transfer(from: bank, to: other_bank) }.to raise_error(described_class::ToAccountNotFound)
    end

    it "rejects an amount of 0 or less" do
      expect { transfer(from: bank, to: cash, amount: 0) }
        .to raise_error(ActiveRecord::StatementInvalid, /amount must be greater than 0/)
    end
  end

  describe "#replace!" do
    it "replaces a transfer with the new content under a new id" do
      journal_id = transfer(from: bank, to: cash)

      new_id = replace(journal_id, from: bank, to: mizuho, amount: 20_000)

      expect(Journal.exists?(journal_id)).to be(false)
      expect(lines(new_id)).to eq([ "振替", [ 1, mizuho.id, 20_000 ], [ 1, 2, bank.id, 20_000 ] ])
    end

    it "edits a cash deposit registered before transfers existed" do
      deposit_id = Journals::CreateCashDeposit.new.create_cash_deposit!(
        journal_date: Date.new(2026, 11, 5), bank_account_id: bank.id, amount: 5_000, user_id: user.id
      )

      new_id = replace(deposit_id, from: cash, to: mizuho, amount: 5_000)

      expect(lines(new_id)).to eq([ "預入", [ 1, mizuho.id, 5_000 ], [ 1, 1, cash.id, 5_000 ] ])
    end

    it "recreates the direct debit journal when a card charge changes" do
      journal_id = transfer(from: tcard, to: suica)

      new_id = replace(journal_id, from: tcard, to: suica, amount: 3_000)

      expect(DirectDebitJournal.count).to eq(1)
      direct_debit = Journal.find(DirectDebitJournal.find_by!(original_id: new_id).direct_debit_id)
      expect(direct_debit.credits.sole.amount.to_i).to eq(3_000)
    end

    it "removes the direct debit journal when a card charge becomes a cash charge" do
      journal_id = transfer(from: tcard, to: suica)

      replace(journal_id, from: cash, to: suica)

      expect(DirectDebitJournal.count).to eq(0)
    end

    it "keeps the original transfer when the new content is invalid" do
      journal_id = transfer(from: bank, to: cash)

      expect { replace(journal_id, from: bank, to: bank) }.to raise_error(described_class::SameAccount)
      expect(Journal.exists?(journal_id)).to be(true)
    end

    it "rejects a journal that is not a transfer, including a direct debit journal" do
      purchase_id = Journals::InsertJournalEntry.new.insert_journal_entry!(
        journal_data: {
          date: "2026-11-05", user_id: user.id, store_name: "スーパー",
          debits: [ { element_type: 5, account_id: food.id, item_name: "食材", amount: 1_000 } ],
          credits: [ { element_type: 2, payment_method_type: 3, account_id: tcard.id, amount: 1_000 } ]
        }
      )
      direct_debit_id = DirectDebitJournal.find_by!(original_id: purchase_id).direct_debit_id

      expect { replace(purchase_id, from: bank, to: cash) }.to raise_error(described_class::NotTransferJournal)
      expect { replace(direct_debit_id, from: bank, to: cash) }.to raise_error(described_class::NotTransferJournal)
    end

    it "rejects another user's journal the same way as a missing one" do
      journal_id = transfer(from: bank, to: cash)

      expect { replace(journal_id, from: bank, to: cash, user_id: create(:user).id) }
        .to raise_error(described_class::JournalNotFound)
      expect { replace(0, from: bank, to: cash) }.to raise_error(described_class::JournalNotFound)
    end
  end
end
