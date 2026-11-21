# frozen_string_literal: true

require 'rails_helper'

# 口座の追加・変更・削除（POST /asset-accounts、PUT・DELETE /asset-accounts/:id）
RSpec.describe 'Managing asset accounts', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) do
    {
      'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}",
      'Content-Type' => 'application/json'
    }
  end

  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:expense) { create(:expense_account, :eating_out, :common) }

  def body
    JSON.parse(response.body)
  end

  def listed
    get '/asset-accounts', headers: headers
    body.to_h { |account| [ account['id'], account ] }
  end

  def pay_with(account)
    Journals::InsertJournalEntry.new.insert_journal_entry!(
      journal_data: {
        date: '2026-10-20', user_id: user.id, store_name: 'Aquavit 001',
        debits: [ { element_type: 5, account_id: expense.id, item_name: 'バー', amount: 1_000 } ],
        credits: [ { element_type: 1, payment_method_type: 1, account_id: account.id, amount: 1_000 } ]
      }
    )
  end

  describe 'GET /asset-accounts' do
    it 'tells which accounts are in use by journals or as a card bank account' do
      suica = create(:asset_account, :suica, user: user)
      pay_with(cash)
      create(:credit_card, :tcard, user: user, liability_account: create(:liability_account, :tcard, user: user),
                                   bank_account: bank)

      expect(listed.transform_values { |account| account['in_use'] })
        .to eq(cash.id => true, bank.id => true, suica.id => false)
    end
  end

  describe 'POST /asset-accounts' do
    def post_account(params)
      post '/asset-accounts', params: params.to_json, headers: headers
    end

    it 'returns 201 with the new id and a next token, and the account can be used' do
      post_account(name: ' みずほ銀行 玉川支店 ', asset_type: 2)

      expect(response).to have_http_status(:created)
      expect(body['next_token']).to be_present

      account = AssetAccount.find(body['id'])
      expect([ account.user_id, account.name, account.asset_type ]).to eq([ user.id, 'みずほ銀行 玉川支店', 'deposit' ])
      expect(listed[account.id]).to include('payment_method_type' => 2, 'in_use' => false)
    end

    it 'returns 422 for a duplicate name, but allows the name of another user' do
      post_account(name: '三菱UFJ銀行 用賀出張所', asset_type: 2)
      expect(response).to have_http_status(:unprocessable_content)
      expect(body).to include('error' => 'duplicate_account_name')
      expect(body['next_token']).to be_present

      create(:asset_account, :suica, user: create(:user))
      post_account(name: 'Suica', asset_type: 3)
      expect(response).to have_http_status(:created)
    end

    it 'returns 422 for a second cash account' do
      post_account(name: 'へそくり', asset_type: 1)

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('cash_account_already_exists')
    end

    it 'returns 422 with errors for a blank name or an unknown type' do
      post_account(name: ' ', asset_type: 4)

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['errors']).to contain_exactly("Name can't be blank", 'Asset type must be 1 (cash), 2 (deposit) or 3 (e_money)')
    end
  end

  describe 'PUT /asset-accounts/:id' do
    def put_account(account, params)
      put "/asset-accounts/#{account.id}", params: params.to_json, headers: headers
    end

    it 'renames an account in use' do
      pay_with(cash)

      put_account(cash, name: 'お財布', asset_type: 1)

      expect(response).to have_http_status(:ok)
      expect(body).to include('id' => cash.id)
      expect(body['next_token']).to be_present
      expect(cash.reload.name).to eq('お財布')
    end

    it 'changes the type of an unused account' do
      suica = create(:asset_account, :suica, user: user)

      put_account(suica, name: 'Suica', asset_type: 2)

      expect(response).to have_http_status(:ok)
      expect(suica.reload.asset_type).to eq('deposit')
    end

    it 'returns 422 when changing the type of an account in use' do
      pay_with(cash)

      put_account(cash, name: '現金', asset_type: 3)

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('asset_account_in_use')
      expect(cash.reload.asset_type).to eq('cash')
    end

    it "returns 422 for a name used by another of the user's accounts" do
      put_account(cash, name: '三菱UFJ銀行 用賀出張所', asset_type: 1)

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('duplicate_account_name')
    end

    it 'keeps the same name without a duplicate error' do
      put_account(bank, name: '三菱UFJ銀行 用賀出張所', asset_type: 2)

      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for another user's account" do
      other = create(:asset_account, :suica, user: create(:user))

      put_account(other, name: 'Suica', asset_type: 3)

      expect(response).to have_http_status(:not_found)
      expect(body['error']).to eq('asset_account_not_found')
    end
  end

  describe 'DELETE /asset-accounts/:id' do
    it 'returns 204 and deletes an unused account' do
      suica = create(:asset_account, :suica, user: user)

      delete "/asset-accounts/#{suica.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(response.headers['X-Next-Token']).to be_present
      expect(AssetAccount.exists?(suica.id)).to be(false)
    end

    it 'returns 422 for an account used by a journal' do
      pay_with(cash)

      delete "/asset-accounts/#{cash.id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('asset_account_in_use')
      expect(AssetAccount.exists?(cash.id)).to be(true)
    end

    it 'returns 422 for the bank account of a card' do
      create(:credit_card, :tcard, user: user, liability_account: create(:liability_account, :tcard, user: user),
                                   bank_account: bank)

      delete "/asset-accounts/#{bank.id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(AssetAccount.exists?(bank.id)).to be(true)
    end

    it "returns 404 for another user's account" do
      other = create(:asset_account, :suica, user: create(:user))

      delete "/asset-accounts/#{other.id}", headers: headers

      expect(response).to have_http_status(:not_found)
      expect(AssetAccount.exists?(other.id)).to be(true)
    end
  end

  it 'returns 401 without a token' do
    post '/asset-accounts', params: { name: 'x', asset_type: 3 }.to_json, headers: { 'Content-Type' => 'application/json' }

    expect(response).to have_http_status(:unauthorized)
  end
end
