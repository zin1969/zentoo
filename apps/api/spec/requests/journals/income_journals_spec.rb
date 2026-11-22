# frozen_string_literal: true

require 'rails_helper'

# 収入の登録・修正（POST /income-journals、PUT /income-journals/:id）
RSpec.describe 'Income journals', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) do
    {
      'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}",
      'Content-Type' => 'application/json'
    }
  end

  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:salary) { create(:revenue_account, :salary, :common) }
  let!(:bonus) { create(:revenue_account, :bonus, :common) }

  let(:params) do
    {
      journal_date: '2026-11-25', asset_account_id: bank.id, revenue_account_id: salary.id,
      amount: 300_000, description: 'ゼンギン株式会社'
    }
  end

  def body
    JSON.parse(response.body)
  end

  def post_income(overrides = {})
    post '/income-journals', params: params.merge(overrides).to_json, headers: headers
  end

  def put_income(id, overrides = {})
    put "/income-journals/#{id}", params: params.merge(overrides).to_json, headers: headers
  end

  describe 'POST /income-journals' do
    it 'returns 201 with the journal id and a next token, and shows up in the journal list' do
      post_income

      expect(response).to have_http_status(:created)
      expect(body['next_token']).to be_present
      journal_id = body['journal_id']

      get '/journals', headers: headers
      listed = JSON.parse(response.body)['journals'].find { |journal| journal['id'] == journal_id }
      expect(listed['store_name']).to eq('ゼンギン株式会社')
      expect(listed['debits'].sole).to include('account_name' => '三菱UFJ銀行 用賀出張所', 'amount' => 300_000)
      expect(listed['credits'].sole).to include('element_type' => 4, 'account_name' => '給与', 'amount' => 300_000)
    end

    it 'marks the revenue account as in use' do
      post_income

      get '/revenue-accounts', headers: headers
      expect(JSON.parse(response.body).find { |a| a['id'] == salary.id }['in_use']).to be(true)

      delete "/revenue-accounts/#{salary.id}", headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('revenue_account_in_use')
    end

    it 'ignores a user_id in the request' do
      post_income(user_id: create(:user).id)

      expect(Journal.find(body['journal_id']).user_id).to eq(user.id)
    end

    it "returns 404 for another user's account or revenue account" do
      post_income(asset_account_id: create(:asset_account, :mufg_yoga, user: create(:user)).id)
      expect(response).to have_http_status(:not_found)
      expect(body).to include('error' => 'asset_account_not_found')
      expect(body['next_token']).to be_present

      post_income(revenue_account_id: create(:revenue_account, name: 'other', user: create(:user)).id)
      expect(response).to have_http_status(:not_found)
      expect(body['error']).to eq('revenue_account_not_found')
    end

    it 'returns 422 with errors for an invalid request' do
      post_income(journal_date: nil, amount: 0, revenue_account_id: nil, description: 'x' * 101)

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['errors']).to contain_exactly(
        "Journal date can't be blank",
        'Description is too long (maximum is 100 characters)',
        'Revenue account must be a positive integer',
        'Amount must be an integer between 1 and 2147483647'
      )
    end
  end

  describe 'PUT /income-journals/:id' do
    let!(:journal_id) do
      Journals::IncomeJournals.new.create!(
        journal_date: Date.new(2026, 11, 25), asset_account_id: bank.id, revenue_account_id: salary.id,
        amount: 300_000, description: nil, user_id: user.id
      )
    end

    it 'returns 200 with the new journal id and replaces the income' do
      put_income(journal_id, revenue_account_id: bonus.id, amount: 500_000)

      expect(response).to have_http_status(:ok)
      expect(body['next_token']).to be_present
      expect(Journal.exists?(journal_id)).to be(false)
      expect(Journal.find(body['journal_id']).credits.sole.account_id).to eq(bonus.id)
    end

    it 'returns 422 for a journal that is not an income journal' do
      deposit_id = Journals::CreateCashDeposit.new.create_cash_deposit!(
        journal_date: Date.new(2026, 11, 26), bank_account_id: bank.id, amount: 1_000, user_id: user.id
      )

      put_income(deposit_id)

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('journal_not_editable')
    end

    it "returns 404 for another user's journal" do
      other_headers = headers.merge('Authorization' => "Bearer #{TokenManager.new.issue_next_token(create(:user))}")

      put "/income-journals/#{journal_id}", params: params.to_json, headers: other_headers

      expect(response).to have_http_status(:not_found)
      expect(body['error']).to eq('journal_not_found')
      expect(Journal.exists?(journal_id)).to be(true)
    end
  end

  it 'returns 401 without a token' do
    post '/income-journals', params: params.to_json, headers: { 'Content-Type' => 'application/json' }

    expect(response).to have_http_status(:unauthorized)
  end
end
