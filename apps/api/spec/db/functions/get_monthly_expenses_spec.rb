# frozen_string_literal: true

require "rails_helper"

RSpec.describe "get_monthly_expenses" do
  let(:user) { create(:user, :masa) }
  let(:other_user) { create(:user) }
  let(:repository) { Reports::MonthlyExpenses.new }
  let(:entry_repository) { Journals::InsertJournalEntry.new }

  let!(:food) { create(:expense_account, :food, :common) }
  let!(:transportation) { create(:expense_account, :transportation, :common) }
  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:tcard) { create(:liability_account, :tcard, user: user) }

  before do
    create(:credit_card, :tcard, user: user, liability_account: tcard, bank_account: bank)
  end

  def spend(date:, expense:, amount:, owner: user, credit: nil)
    cash_account = owner == user ? cash : create(:asset_account, :cash, user: owner)

    entry_repository.insert_journal_entry!(
      journal_data: {
        date: date,
        user_id: owner.id,
        store_name: "店",
        debits: [ { element_type: 5, account_id: expense.id, amount: amount, item_name: "品" } ],
        credits: [ credit || { element_type: 1, payment_method_type: 1, account_id: cash_account.id, amount: amount } ]
      }
    )
  end

  def totals_for(month, owner: user)
    repository.list(user_id: owner.id, month: month).to_h { |row| [ row.account_id, row.amount ] }
  end

  before do
    spend(date: "2026-09-30", expense: food, amount: 700)
    spend(date: "2026-10-01", expense: food, amount: 1_000)
    spend(date: "2026-10-31", expense: food, amount: 500)
    spend(date: "2026-10-15", expense: transportation, amount: 3_000)
    spend(date: "2026-11-01", expense: food, amount: 900)
  end

  it "sums the expenses of the month by account, largest first" do
    rows = repository.list(user_id: user.id, month: Date.new(2026, 10, 1))

    expect(rows.map { |row| [ row.account_id, row.account_name, row.amount ] }).to eq(
      [ [ transportation.id, "交通費", 3_000 ], [ food.id, "食費", 1_500 ] ]
    )
  end

  it "includes the first and the last day of the month and excludes the neighbours" do
    expect(totals_for(Date.new(2026, 10, 1))[food.id]).to eq(1_500)
    expect(totals_for(Date.new(2026, 9, 1))).to eq(food.id => 700)
    expect(totals_for(Date.new(2026, 11, 1))).to eq(food.id => 900)
  end

  it "accepts any day in the month" do
    expect(totals_for(Date.new(2026, 10, 17))).to eq(totals_for(Date.new(2026, 10, 1)))
  end

  it "returns nothing for a month without expenses" do
    expect(repository.list(user_id: user.id, month: Date.new(2026, 8, 1))).to eq([])
  end

  it "counts a card payment in the month of purchase, not in the month of the direct debit" do
    # 20 日の購入は締日(10日)後なので、引き落とし(11/27)は 11 月。11 月の費用には含めない
    spend(date: "2026-10-20", expense: food, amount: 2_000, credit: { element_type: 2, payment_method_type: 3, account_id: tcard.id, amount: 2_000 })

    expect(totals_for(Date.new(2026, 10, 1))[food.id]).to eq(3_500)
    expect(totals_for(Date.new(2026, 11, 1))).to eq(food.id => 900)
  end

  it "does not include other users' expenses" do
    spend(date: "2026-10-10", expense: food, amount: 10_000, owner: other_user)

    expect(totals_for(Date.new(2026, 10, 1))[food.id]).to eq(1_500)
    expect(totals_for(Date.new(2026, 10, 1), owner: other_user)).to eq(food.id => 10_000)
  end
end
