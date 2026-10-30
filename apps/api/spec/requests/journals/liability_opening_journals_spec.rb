# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /liability-opening-journals', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) do
    {
      'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}",
      'Content-Type' => 'application/json'
    }
  end

  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:tcard) { create(:liability_account, :tcard, user: user) }

  def post_opening(body = {})
    post '/liability-opening-journals',
         params: {
           journal_date: '2026-10-30', liability_account_id: tcard.id, amount: 30_000, payment_date: '2026-11-10'
         }.merge(body).to_json,
         headers: headers
  end

  def balances(date)
    get '/account-balances', params: { date: date }, headers: headers
    body = JSON.parse(response.body)

    { assets: body['assets'].to_h { |a| [ a['account_id'], a['balance'] ] },
      liabilities: body['liabilities'].to_h { |a| [ a['account_id'], a['balance'] ] } }
  end

  before do
    create(:equity_account, :original_deposit, :common)
    create(:credit_card, :tcard, user: user, liability_account: tcard, bank_account: bank)

    Journals::CreateOpeningAsset.new.create_opening_asset_balance!(
      journal_date: Date.new(2026, 10, 1),
      asset_type: ElementType.new(ElementType::ASSETS),
      asset_account_id: bank.id,
      amount: Amount.new(500_000),
      user_id: user.id
    )
  end

  it 'returns 201, the journal id and a next token' do
    post_opening

    expect(response).to have_http_status(:created)

    body = JSON.parse(response.body)
    expect(body['next_token']).to be_present
    expect(Journal.find(body['journal_id']).user_id).to eq(user.id)
  end

  it 'shows the unpaid amount as a liability until the payment date, then moves it out of the bank' do
    post_opening

    before_payment = balances('2026-11-09')
    expect(before_payment[:liabilities]).to eq(tcard.id => 30_000)
    expect(before_payment[:assets]).to eq(bank.id => 500_000)

    on_payment = balances('2026-11-10')
    expect(on_payment[:liabilities]).to eq(tcard.id => 0)
    expect(on_payment[:assets]).to eq(bank.id => 470_000)
  end

  it 'lists the opening journal and its direct debit linked to each other' do
    post_opening

    get '/journals', headers: headers

    journals = JSON.parse(response.body)['journals']
    expect(journals.map { |j| j['journal_date'] }).to eq(%w[2026-11-10 2026-10-30 2026-10-01])

    debit_day, opening = journals.first(2)
    expect(opening['direct_debit_journal_id']).to eq(debit_day['id'])
    expect(debit_day['original_journal_id']).to eq(opening['id'])
  end

  it 'does not touch monthly expenses' do
    post_opening

    get '/monthly-expenses', params: { month: '2026-10' }, headers: headers

    expect(JSON.parse(response.body)).to include('total' => 0, 'items' => [])
  end

  it 'ignores a user_id in the request' do
    post_opening(user_id: create(:user).id)

    expect(Journal.find(JSON.parse(response.body)['journal_id']).user_id).to eq(user.id)
  end

  it 'returns 409 for the same card and payment date' do
    post_opening

    expect { post_opening(amount: 1_000) }.not_to change(Journal, :count)

    expect(response).to have_http_status(:conflict)
    body = JSON.parse(response.body)
    expect(body['error']).to eq('opening_liability_already_exists')
    expect(body['next_token']).to be_present
  end

  it 'accepts the same card with another payment date' do
    post_opening
    post_opening(payment_date: '2026-12-10')

    expect(response).to have_http_status(:created)
  end

  it "returns 404 and creates nothing for another user's card" do
    other_card = create(:liability_account, :jal, user: create(:user))

    expect { post_opening(liability_account_id: other_card.id) }.not_to change(Journal, :count)

    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)['error']).to eq('liability_account_not_found')
  end

  it 'returns 422 when the payment date is before the journal date' do
    expect { post_opening(payment_date: '2026-10-29') }.not_to change(Journal, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)['error']).to eq('payment_date_before_journal_date')
  end

  it 'returns 422 when the card has no setting' do
    card = create(:liability_account, :paypay, user: user)

    expect { post_opening(liability_account_id: card.id) }.not_to change(Journal, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)['error']).to eq('credit_card_setting_not_found')
  end

  it 'returns 422 with errors for an invalid request' do
    post_opening(amount: 0)

    expect(response).to have_http_status(:unprocessable_content)
    body = JSON.parse(response.body)
    expect(body['errors']).to eq([ 'Amount must be an integer between 1 and 2147483647' ])
    expect(body['next_token']).to be_present
  end

  it 'returns 401 without a token' do
    post '/liability-opening-journals', params: {}.to_json, headers: { 'Content-Type' => 'application/json' }

    expect(response).to have_http_status(:unauthorized)
  end
end
