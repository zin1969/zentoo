# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /cash-deposit-journals', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) do
    {
      'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}",
      'Content-Type' => 'application/json'
    }
  end

  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }

  def post_deposit(body = {})
    post '/cash-deposit-journals',
         params: { journal_date: '2026-10-20', bank_account_id: bank.id, amount: 45_000 }.merge(body).to_json,
         headers: headers
  end

  def balances
    get '/account-balances', params: { date: '2026-10-31' }, headers: headers
    JSON.parse(response.body)['assets'].to_h { |a| [ a['account_id'], a['balance'] ] }
  end

  before do
    create(:equity_account, :original_deposit, :common)

    [ [ cash, 100_000 ], [ bank, 500_000 ] ].each do |account, amount|
      Journals::CreateOpeningAsset.new.create_opening_asset_balance!(
        journal_date: Date.new(2026, 10, 1),
        asset_type: ElementType.new(ElementType::ASSETS),
        asset_account_id: account.id,
        amount: Amount.new(amount),
        user_id: user.id
      )
    end
  end

  it 'returns 201, the journal id and a next token' do
    post_deposit

    expect(response).to have_http_status(:created)

    body = JSON.parse(response.body)
    expect(body['next_token']).to be_present

    journal = Journal.find(body['journal_id'])
    expect(journal.user_id).to eq(user.id)
    expect(journal.debits.sole.account_id).to eq(bank.id)
    expect(journal.credits.sole.account_id).to eq(cash.id)
  end

  it 'moves the amount from cash to the bank in the balances' do
    expect(balances).to eq(cash.id => 100_000, bank.id => 500_000)

    post_deposit

    expect(balances).to eq(cash.id => 55_000, bank.id => 545_000)
  end

  it 'shows up in the journal list as a deposit' do
    post_deposit

    get '/journals', headers: headers

    journal = JSON.parse(response.body)['journals'].first
    expect(journal['store_name']).to eq(bank.name)
    expect(journal['debits'].sole).to include('account_name' => bank.name, 'item_name' => '預入', 'amount' => 45_000)
    expect(journal['credits'].sole).to include('account_name' => '現金', 'amount' => 45_000)
  end

  it 'ignores a user_id in the request' do
    other = create(:user)

    post_deposit(user_id: other.id)

    expect(Journal.last.user_id).to eq(user.id)
  end

  it "returns 404 and creates nothing for another user's account" do
    other_bank = create(:asset_account, :mizuho_tamagawa, user: create(:user))

    expect { post_deposit(bank_account_id: other_bank.id) }.not_to change(Journal, :count)

    expect(response).to have_http_status(:not_found)
    body = JSON.parse(response.body)
    expect(body['error']).to eq('asset_account_not_found')
    expect(body['next_token']).to be_present
  end

  it 'returns 404 for an account that is not a deposit account' do
    post_deposit(bank_account_id: cash.id)

    expect(response).to have_http_status(:not_found)
  end

  it 'returns 422 when the cash account cannot be determined' do
    create(:asset_account, :cash, user: user, name: 'へそくり')

    expect { post_deposit }.not_to change(Journal, :count)

    expect(response).to have_http_status(:unprocessable_content)
    body = JSON.parse(response.body)
    expect(body['error']).to eq('cash_account_not_determined')
    expect(body['next_token']).to be_present
  end

  it 'returns 422 with errors for an invalid request' do
    post_deposit(amount: 0)

    expect(response).to have_http_status(:unprocessable_content)
    body = JSON.parse(response.body)
    expect(body['errors']).to eq([ 'Amount must be an integer between 1 and 2147483647' ])
    expect(body['next_token']).to be_present
  end

  it 'returns 401 without a token' do
    post '/cash-deposit-journals', params: { journal_date: '2026-10-20', bank_account_id: bank.id, amount: 1 }.to_json,
                                   headers: { 'Content-Type' => 'application/json' }

    expect(response).to have_http_status(:unauthorized)
  end
end
