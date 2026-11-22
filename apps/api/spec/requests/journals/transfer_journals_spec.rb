# frozen_string_literal: true

require 'rails_helper'

# 振替の登録・修正（POST /transfer-journals、PUT /transfer-journals/:id）
RSpec.describe 'Transfer journals', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) do
    {
      'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}",
      'Content-Type' => 'application/json'
    }
  end

  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:suica) { create(:asset_account, :suica, user: user) }
  let!(:tcard) { create(:liability_account, :tcard, user: user) }

  before { create(:credit_card, :tcard, user: user, liability_account: tcard, bank_account: bank) }

  let(:params) do
    { journal_date: '2026-11-05', from_type: 'asset', from_account_id: bank.id, to_account_id: cash.id, amount: 10_000 }
  end

  def body
    JSON.parse(response.body)
  end

  def post_transfer(overrides = {})
    post '/transfer-journals', params: params.merge(overrides).to_json, headers: headers
  end

  def balances
    get '/account-balances', params: { date: '2026-11-30' }, headers: headers
    JSON.parse(response.body).values_at('assets', 'liabilities').flatten.to_h { |a| [ a['account_id'], a['balance'] ] }
  end

  describe 'POST /transfer-journals' do
    it 'returns 201 with the journal id and a next token, and moves the money' do
      post_transfer

      expect(response).to have_http_status(:created)
      expect(body['next_token']).to be_present
      expect(Journal.find(body['journal_id']).store_name).to eq('引き出し')
      expect(balances.values_at(bank.id, cash.id)).to eq([ -10_000, 10_000 ])
    end

    it 'charges e-money with a credit card, leaving the card payable until the direct debit' do
      post_transfer(from_type: 'credit_card', from_account_id: tcard.id, to_account_id: suica.id, amount: 3_000,
                    description: 'Suica チャージ')

      expect(response).to have_http_status(:created)
      expect(Journal.find(body['journal_id']).store_name).to eq('Suica チャージ')

      get '/account-balances', params: { date: '2026-11-26' }, headers: headers
      before_debit = JSON.parse(response.body).values_at('assets', 'liabilities').flatten.to_h { |a| [ a['account_id'], a['balance'] ] }
      expect(before_debit.values_at(suica.id, tcard.id, bank.id)).to eq([ 3_000, 3_000, 0 ])

      # 27 日の引き落としで、カードの未払いが消え、預金が減る
      expect(balances.values_at(suica.id, tcard.id, bank.id)).to eq([ 3_000, 0, -3_000 ])
    end

    it 'returns 404 for an account or card of another user' do
      other = create(:user)

      post_transfer(from_account_id: create(:asset_account, :mufg_yoga, user: other).id)
      expect(response).to have_http_status(:not_found)
      expect(body).to include('error' => 'from_account_not_found')
      expect(body['next_token']).to be_present

      post_transfer(to_account_id: create(:asset_account, :suica, user: other).id)
      expect(response).to have_http_status(:not_found)
      expect(body['error']).to eq('to_account_not_found')
    end

    it 'returns 422 for the same account, a card charge to a non e-money account, or a card without a setting' do
      post_transfer(to_account_id: bank.id)
      expect(body['error']).to eq('same_account')

      post_transfer(from_type: 'credit_card', from_account_id: tcard.id, to_account_id: cash.id)
      expect(body['error']).to eq('credit_card_charge_requires_e_money')

      paypay = create(:liability_account, :paypay, user: user)
      post_transfer(from_type: 'credit_card', from_account_id: paypay.id, to_account_id: suica.id)
      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('credit_card_setting_not_found')
    end

    it 'returns 422 with errors for an invalid request' do
      post_transfer(from_type: 'bank', amount: 0, to_account_id: nil)

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['errors']).to contain_exactly(
        'From type must be asset or credit_card',
        'To account must be a positive integer',
        'Amount must be an integer between 1 and 2147483647'
      )
    end
  end

  describe 'PUT /transfer-journals/:id' do
    let!(:journal_id) do
      Journals::TransferJournals.new.create!(
        journal_date: Date.new(2026, 11, 5), from_element_type: ElementType::ASSETS, from_account_id: bank.id,
        to_account_id: cash.id, amount: 10_000, description: nil, user_id: user.id
      )
    end

    it 'returns 200 with the new journal id and replaces the transfer' do
      put "/transfer-journals/#{journal_id}", params: params.merge(to_account_id: suica.id).to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(body['next_token']).to be_present
      expect(Journal.exists?(journal_id)).to be(false)
      expect(Journal.find(body['journal_id']).debits.sole.account_id).to eq(suica.id)
    end

    it 'returns 422 for a journal that is not a transfer' do
      income_id = Journals::IncomeJournals.new.create!(
        journal_date: Date.new(2026, 11, 25), asset_account_id: bank.id,
        revenue_account_id: create(:revenue_account, :salary, :common).id, amount: 1, description: nil, user_id: user.id
      )

      put "/transfer-journals/#{income_id}", params: params.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('journal_not_editable')
    end

    it "returns 404 for another user's journal" do
      other_headers = headers.merge('Authorization' => "Bearer #{TokenManager.new.issue_next_token(create(:user))}")

      put "/transfer-journals/#{journal_id}", params: params.to_json, headers: other_headers

      expect(response).to have_http_status(:not_found)
      expect(body['error']).to eq('journal_not_found')
    end
  end

  it 'returns 401 without a token' do
    post '/transfer-journals', params: params.to_json, headers: { 'Content-Type' => 'application/json' }

    expect(response).to have_http_status(:unauthorized)
  end
end
