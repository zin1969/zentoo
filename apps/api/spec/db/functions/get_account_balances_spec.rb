# frozen_string_literal: true

require "rails_helper"

RSpec.describe "get_account_balances" do
  let(:user) { create(:user, :masa) }
  let(:other_user) { create(:user) }
  let(:repository) { Reports::AccountBalances.new }
  let(:entry_repository) { Journals::InsertJournalEntry.new }
  let(:opening_repository) { Journals::CreateOpeningAsset.new }

  let!(:food) { create(:expense_account, :food, :common) }
  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:unused) { create(:asset_account, :suica, user: user) }
  let!(:tcard) { create(:liability_account, :tcard, user: user) }

  before do
    create(:equity_account, :original_deposit, :common)
    create(:credit_card, :tcard, user: user, liability_account: tcard, bank_account: bank)

    open_balance(cash, 100_000, owner: user)
    open_balance(bank, 500_000, owner: user)
  end

  def open_balance(account, amount, owner:)
    opening_repository.create_opening_asset_balance!(
      journal_date: Date.new(2026, 10, 1),
      asset_type: ElementType.new(ElementType::ASSETS),
      asset_account_id: account.id,
      amount: Amount.new(amount),
      user_id: owner.id
    )
  end

  def buy(date:, amount:, credit:, owner: user)
    entry_repository.insert_journal_entry!(
      journal_data: {
        date: date,
        user_id: owner.id,
        store_name: "まいばすけっと",
        debits: [ { element_type: 5, account_id: food.id, amount: amount, item_name: "パン" } ],
        credits: [ credit ]
      }
    )
  end

  def pay_cash(amount)
    { element_type: 1, payment_method_type: 1, account_id: cash.id, amount: amount }
  end

  def pay_card(amount)
    { element_type: 2, payment_method_type: 3, account_id: tcard.id, amount: amount }
  end

  # { [element_type, account_id] => balance }
  def balances_as_of(date, owner: user)
    repository.list(user_id: owner.id, as_of: date).to_h { |row| [ [ row.element_type, row.account_id ], row.balance ] }
  end

  it "returns every asset and liability account of the user, including those without entries" do
    balances = balances_as_of(Date.new(2026, 10, 1))

    expect(balances).to eq(
      [ 1, cash.id ] => 100_000,
      [ 1, bank.id ] => 500_000,
      [ 1, unused.id ] => 0,
      [ 2, tcard.id ] => 0
    )
  end

  it "ignores journals after the as-of date" do
    expect(balances_as_of(Date.new(2026, 9, 30)).values).to all(eq(0))
  end

  it "subtracts cash payments from the asset" do
    buy(date: "2026-10-05", amount: 1_000, credit: pay_cash(1_000))

    expect(balances_as_of(Date.new(2026, 10, 4))[[ 1, cash.id ]]).to eq(100_000)
    expect(balances_as_of(Date.new(2026, 10, 5))[[ 1, cash.id ]]).to eq(99_000)
  end

  it "shows a card payment as a liability until the direct debit date" do
    # 締日(10日)後なので、引き落としは翌月 27 日（金）
    buy(date: "2026-10-20", amount: 14_000, credit: pay_card(14_000))

    before_debit = balances_as_of(Date.new(2026, 11, 26))
    expect(before_debit[[ 2, tcard.id ]]).to eq(14_000)
    expect(before_debit[[ 1, bank.id ]]).to eq(500_000)

    on_debit = balances_as_of(Date.new(2026, 11, 27))
    expect(on_debit[[ 2, tcard.id ]]).to eq(0)
    expect(on_debit[[ 1, bank.id ]]).to eq(486_000)
  end

  it "does not include other users' journals or accounts" do
    other_cash = create(:asset_account, :cash, user: other_user)
    open_balance(other_cash, 7_777, owner: other_user)

    expect(balances_as_of(Date.new(2026, 10, 31)).keys).not_to include([ 1, other_cash.id ])
    expect(balances_as_of(Date.new(2026, 10, 31))[[ 1, cash.id ]]).to eq(100_000)
    expect(balances_as_of(Date.new(2026, 10, 31), owner: other_user)).to eq([ 1, other_cash.id ] => 7_777)
  end
end
