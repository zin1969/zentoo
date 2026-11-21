# frozen_string_literal: true

require "rails_helper"

RSpec.describe "get_bank_account_ledger" do
  let(:user) { create(:user, :masa) }
  let(:repository) { Reports::BankAccountLedger.new }

  let!(:food) { create(:expense_account, :food, :common) }
  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:mizuho) { create(:asset_account, :mizuho_tamagawa, user: user) }
  let!(:tcard) { create(:liability_account, :tcard, user: user) }
  let!(:jal) { create(:liability_account, :jal, user: user) }

  before do
    create(:equity_account, :original_deposit, :common)
    # tcard は 10 日締め・27 日払い、JAL は 15 日締め・翌月 10 日払い
    create(:credit_card, :tcard, user: user, liability_account: tcard, bank_account: bank)
    create(:credit_card, :jal, user: user, liability_account: jal, bank_account: bank)

    open_balance(cash, 100_000)
    open_balance(bank, 500_000)
    open_balance(mizuho, 70_000)
  end

  def open_balance(account, amount)
    Journals::CreateOpeningAsset.new.create_opening_asset_balance!(
      journal_date: Date.new(2026, 10, 1),
      asset_type: ElementType.new(ElementType::ASSETS),
      asset_account_id: account.id,
      amount: Amount.new(amount),
      user_id: user.id
    )
  end

  def buy(date:, amount:, card:, store: "Aquavit 001")
    Journals::InsertJournalEntry.new.insert_journal_entry!(
      journal_data: {
        date: date, user_id: user.id, store_name: store,
        debits: [ { element_type: 5, account_id: food.id, item_name: "食材", amount: amount } ],
        credits: [ { element_type: 2, payment_method_type: 3, account_id: card.id, amount: amount } ]
      }
    )
  end

  def deposit(date:, amount:)
    Journals::CreateCashDeposit.new.create_cash_deposit!(
      journal_date: date, bank_account_id: bank.id, amount: amount, user_id: user.id
    )
  end

  # DB 関数の RAISE でテスト全体のトランザクションが中断されないよう、savepoint の中で呼ぶ
  def ledger(from:, to:, account: bank, owner: user)
    ActiveRecord::Base.transaction(requires_new: true) do
      repository.list(user_id: owner.id, asset_account_id: account.id, from: from, to: to)
    end
  end

  def summary(rows)
    rows.map { |r| [ r.row_type, r.entry_date, r.description, r.deposit, r.withdrawal, r.balance ] }
  end

  context "with deposits and card payments" do
    let!(:first_tcard) { buy(date: "2026-10-05", amount: 3_000, card: tcard, store: "スーパー") }
    let!(:second_tcard) { buy(date: "2026-10-08", amount: 2_000, card: tcard, store: "八百屋") }
    let!(:jal_purchase) { buy(date: "2026-10-09", amount: 1_000, card: jal) }

    before { deposit(date: Date.new(2026, 10, 20), amount: 45_000) }

    it "starts with the carried-over balance and accumulates the balance in date order" do
      rows = ledger(from: Date.new(2026, 10, 1), to: Date.new(2026, 11, 30))

      expect(summary(rows)).to eq([
        [ "carried_over", Date.new(2026, 9, 30), "繰越", 0, 0, 0 ],
        [ "journal", Date.new(2026, 10, 1), "開始残高", 500_000, 0, 500_000 ],
        [ "journal", Date.new(2026, 10, 20), "預入", 45_000, 0, 545_000 ],
        [ "card_payment", Date.new(2026, 10, 27), "tcard", 0, 5_000, 540_000 ],
        [ "card_payment", Date.new(2026, 11, 10), "JAL", 0, 1_000, 539_000 ]
      ])
    end

    it "groups the direct debits of the same card on the same day, with the original purchases" do
      rows = ledger(from: Date.new(2026, 10, 1), to: Date.new(2026, 11, 30))

      tcard_row = rows.find { |r| r.description == "tcard" }
      expect(tcard_row.card_account_id).to eq(tcard.id)
      expect(tcard_row.journal_ids).to eq([ first_tcard, second_tcard ])

      jal_row = rows.find { |r| r.description == "JAL" }
      expect(jal_row.journal_ids).to eq([ jal_purchase ])
    end

    it "carries over the balance before the period and leaves out rows after it" do
      rows = ledger(from: Date.new(2026, 10, 21), to: Date.new(2026, 10, 31))

      expect(summary(rows)).to eq([
        [ "carried_over", Date.new(2026, 10, 20), "繰越", 0, 0, 545_000 ],
        [ "card_payment", Date.new(2026, 10, 27), "tcard", 0, 5_000, 540_000 ]
      ])
    end

    it "uses a direct debit date changed by hand" do
      direct_debit_id = DirectDebitJournal.find_by!(original_id: first_tcard).direct_debit_id
      Journals::UpdateDirectDebitDate.new.update_direct_debit_date!(
        journal_id: direct_debit_id, payment_date: Date.new(2026, 11, 27), user_id: user.id
      )

      rows = ledger(from: Date.new(2026, 10, 21), to: Date.new(2026, 11, 30))

      expect(rows.select { |r| r.description == "tcard" }.map { |r| [ r.entry_date, r.withdrawal ] })
        .to eq([ [ Date.new(2026, 10, 27), 2_000 ], [ Date.new(2026, 11, 27), 3_000 ] ])
    end
  end

  it "goes negative when the direct debits exceed the balance" do
    buy(date: "2026-10-09", amount: 600_000, card: jal)

    rows = ledger(from: Date.new(2026, 10, 1), to: Date.new(2026, 11, 30))

    expect(rows.last.balance).to eq(-100_000)
  end

  it "shows only the movements of the chosen account" do
    rows = ledger(from: Date.new(2026, 10, 1), to: Date.new(2026, 10, 31), account: mizuho)

    expect(summary(rows)).to eq([
      [ "carried_over", Date.new(2026, 9, 30), "繰越", 0, 0, 0 ],
      [ "journal", Date.new(2026, 10, 1), "開始残高", 70_000, 0, 70_000 ]
    ])
  end

  it "returns only the carried-over row when nothing moves in the period" do
    rows = ledger(from: Date.new(2027, 1, 1), to: Date.new(2027, 1, 31))

    expect(summary(rows)).to eq([ [ "carried_over", Date.new(2026, 12, 31), "繰越", 0, 0, 500_000 ] ])
  end

  it "rejects a cash account and another user's deposit account" do
    other = create(:user)
    other_bank = create(:asset_account, :mufg_yoga, user: other)

    expect { ledger(from: Date.new(2026, 10, 1), to: Date.new(2026, 10, 31), account: cash) }
      .to raise_error(Reports::BankAccountLedger::AssetAccountNotFound)
    expect { ledger(from: Date.new(2026, 10, 1), to: Date.new(2026, 10, 31), account: other_bank) }
      .to raise_error(Reports::BankAccountLedger::AssetAccountNotFound)
  end
end
