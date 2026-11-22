# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /monthly-expenses', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) { { 'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}" } }

  let!(:food) { create(:expense_account, :food, :common) }
  let!(:transportation) { create(:expense_account, :transportation, :common) }
  let!(:cash) { create(:asset_account, :cash, user: user) }

  def spend(date:, expense:, amount:)
    Journals::InsertJournalEntry.new.insert_journal_entry!(
      journal_data: {
        date: date,
        user_id: user.id,
        store_name: '店',
        debits: [ { element_type: 5, account_id: expense.id, amount: amount, item_name: '品' } ],
        credits: [ { element_type: 1, payment_method_type: 1, account_id: cash.id, amount: amount } ]
      }
    )
  end

  before do
    spend(date: '2026-10-01', expense: food, amount: 1_000)
    spend(date: '2026-10-15', expense: transportation, amount: 3_000)
    spend(date: '2026-11-01', expense: food, amount: 900)
  end

  it 'returns the total and the amount per expense account, largest first' do
    get '/monthly-expenses', params: { month: '2026-10' }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to eq(
      'month' => '2026-10',
      'total' => 4_000,
      'items' => [
        { 'account_id' => transportation.id, 'account_name' => '交通費', 'amount' => 3_000 },
        { 'account_id' => food.id, 'account_name' => '食費', 'amount' => 1_000 }
      ],
      'income_total' => 0,
      'income_items' => [],
      'net' => -4_000
    )
  end

  it 'returns an empty list and a zero total for a month without expenses' do
    get '/monthly-expenses', params: { month: '2026-08' }, headers: headers

    expect(JSON.parse(response.body)).to eq(
      'month' => '2026-08', 'total' => 0, 'items' => [], 'income_total' => 0, 'income_items' => [], 'net' => 0
    )
  end

  describe 'incomes' do
    let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
    let!(:salary) { create(:revenue_account, :salary, :common) }
    let!(:bonus) { create(:revenue_account, :bonus, :common) }

    def earn(date:, revenue:, amount:, owner: user, account: bank)
      Journals::IncomeJournals.new.create!(
        journal_date: Date.parse(date), asset_account_id: account.id, revenue_account_id: revenue.id,
        amount: amount, description: nil, user_id: owner.id
      )
    end

    it 'returns the income per revenue account, largest first, and the net of income and expenses' do
      earn(date: '2026-10-25', revenue: salary, amount: 300_000)
      earn(date: '2026-10-10', revenue: bonus, amount: 500_000)
      earn(date: '2026-10-31', revenue: salary, amount: 1_000)
      earn(date: '2026-11-25', revenue: salary, amount: 300_000)
      other = create(:user)
      earn(date: '2026-10-25', revenue: salary, amount: 999, owner: other,
           account: create(:asset_account, :mufg_yoga, user: other))

      get '/monthly-expenses', params: { month: '2026-10' }, headers: headers

      body = JSON.parse(response.body)
      expect(body['income_items']).to eq([
        { 'account_id' => bonus.id, 'account_name' => '賞与', 'amount' => 500_000 },
        { 'account_id' => salary.id, 'account_name' => '給与', 'amount' => 301_000 }
      ])
      expect(body.values_at('total', 'income_total', 'net')).to eq([ 4_000, 801_000, 797_000 ])
    end
  end

  it 'defaults to the current month in Japan time' do
    # UTC では 2026-10-31 15:00 だが、日本時間では 11/1 0:00
    travel_to(Time.utc(2026, 10, 31, 15, 0)) do
      get '/monthly-expenses', headers: headers
    end

    body = JSON.parse(response.body)
    expect(body['month']).to eq('2026-11')
    expect(body['total']).to eq(900)
  end

  it 'returns 422 for an invalid month' do
    get '/monthly-expenses', params: { month: '2026-13' }, headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)['errors']).to eq([ 'Month must be a month (YYYY-MM)' ])
  end

  it 'returns 401 without a token' do
    get '/monthly-expenses'

    expect(response).to have_http_status(:unauthorized)
  end
end
