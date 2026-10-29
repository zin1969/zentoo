# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /account-balances', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) { { 'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}" } }

  let!(:food) { create(:expense_account, :food, :common) }
  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:tcard) { create(:liability_account, :tcard, user: user) }

  before do
    create(:equity_account, :original_deposit, :common)
    create(:credit_card, :tcard, user: user, liability_account: tcard, bank_account: bank)

    [ [ cash, 100_000 ], [ bank, 500_000 ] ].each do |account, amount|
      Journals::CreateOpeningAsset.new.create_opening_asset_balance!(
        journal_date: Date.new(2026, 10, 1),
        asset_type: ElementType.new(ElementType::ASSETS),
        asset_account_id: account.id,
        amount: Amount.new(amount),
        user_id: user.id
      )
    end

    Journals::InsertJournalEntry.new.insert_journal_entry!(
      journal_data: {
        date: '2026-10-20',
        user_id: user.id,
        store_name: 'フェザー・ステップ',
        debits: [ { element_type: 5, account_id: food.id, amount: 14_000, item_name: '革靴' } ],
        credits: [ { element_type: 2, payment_method_type: 3, account_id: tcard.id, amount: 14_000 } ]
      }
    )
  end

  it 'returns the balances of assets and liabilities with totals as of the given date' do
    get '/account-balances', params: { date: '2026-10-31' }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to eq(
      'date' => '2026-10-31',
      'assets' => [
        { 'account_id' => cash.id, 'account_name' => '現金', 'balance' => 100_000 },
        { 'account_id' => bank.id, 'account_name' => '三菱UFJ銀行 用賀出張所', 'balance' => 500_000 }
      ],
      'liabilities' => [
        { 'account_id' => tcard.id, 'account_name' => 'tcard', 'balance' => 14_000 }
      ],
      'total_assets' => 600_000,
      'total_liabilities' => 14_000,
      'net_assets' => 586_000
    )
  end

  it 'reflects the direct debit once its date has come' do
    get '/account-balances', params: { date: '2026-11-27' }, headers: headers

    body = JSON.parse(response.body)
    expect(body['liabilities'].sole['balance']).to eq(0)
    expect(body['assets'].find { |a| a['account_id'] == bank.id }['balance']).to eq(486_000)
    expect(body['net_assets']).to eq(586_000)
  end

  it 'defaults to today in Japan time' do
    # UTC では 2026-10-31 15:00 だが、日本時間では 11/1 0:00（開始残高の翌日以降）
    travel_to(Time.utc(2026, 10, 31, 15, 0)) do
      get '/account-balances', headers: headers
    end

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['date']).to eq('2026-11-01')
  end

  it 'returns 422 for an invalid date' do
    get '/account-balances', params: { date: '2026-02-30' }, headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)['errors']).to eq([ 'Date must be a date (YYYY-MM-DD)' ])
  end

  it 'does not include other users accounts' do
    other = create(:user)
    other_cash = create(:asset_account, :cash, user: other)

    get '/account-balances', params: { date: '2026-10-31' }, headers: headers

    ids = JSON.parse(response.body)['assets'].map { |a| a['account_id'] }
    expect(ids).not_to include(other_cash.id)
  end

  it 'returns 401 without a token' do
    get '/account-balances'

    expect(response).to have_http_status(:unauthorized)
  end
end
