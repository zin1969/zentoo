# frozen_string_literal: true

require 'rails_helper'

# 費用科目の追加・変更・削除（POST /expense-accounts、PUT・DELETE /expense-accounts/:id）
RSpec.describe 'Managing expense accounts', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) do
    {
      'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}",
      'Content-Type' => 'application/json'
    }
  end

  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:food) { create(:expense_account, :common, name: '食費') }
  let!(:eating_out) { create(:expense_account, :common, name: '外食費', parent: food) }
  let!(:transport) { create(:expense_account, :common, name: '交通費') }

  def body
    JSON.parse(response.body)
  end

  def listed
    get '/expense-accounts', headers: headers
    body.to_h { |account| [ account['id'], account ] }
  end

  def spend_on(expense, owner: user, owner_cash: cash)
    Journals::InsertJournalEntry.new.insert_journal_entry!(
      journal_data: {
        date: '2026-10-20', user_id: owner.id, store_name: 'Aquavit 001',
        debits: [ { element_type: 5, account_id: expense.id, item_name: 'バー', amount: 1_000 } ],
        credits: [ { element_type: 1, payment_method_type: 1, account_id: owner_cash.id, amount: 1_000 } ]
      }
    )
  end

  def post_account(params)
    post '/expense-accounts', params: params.to_json, headers: headers
  end

  def put_account(account, params)
    put "/expense-accounts/#{account.id}", params: params.to_json, headers: headers
  end

  describe 'GET /expense-accounts' do
    it 'returns the parent, and whether each account is in use or has children' do
      spend_on(eating_out)

      expect(listed).to eq(
        food.id => { 'id' => food.id, 'name' => '食費', 'parent_id' => nil, 'in_use' => false, 'has_children' => true },
        eating_out.id => {
          'id' => eating_out.id, 'name' => '外食費', 'parent_id' => food.id, 'in_use' => true, 'has_children' => false
        },
        transport.id => {
          'id' => transport.id, 'name' => '交通費', 'parent_id' => nil, 'in_use' => false, 'has_children' => false
        }
      )
    end

    it "treats a common account used by another user's journal as in use" do
      other = create(:user)
      spend_on(transport, owner: other, owner_cash: create(:asset_account, :cash, user: other))

      expect(listed[transport.id]['in_use']).to be(true)
    end
  end

  describe 'POST /expense-accounts' do
    it 'returns 201 and creates a common top-level account' do
      post_account(name: ' 日用品 ')

      expect(response).to have_http_status(:created)
      expect(body['next_token']).to be_present

      account = ExpenseAccount.find(body['id'])
      expect([ account.user_id, account.name, account.parent_id ]).to eq([ nil, '日用品', nil ])
    end

    it 'creates a child account under a top-level account' do
      post_account(name: '食材', parent_id: food.id)

      expect(response).to have_http_status(:created)
      expect(ExpenseAccount.find(body['id']).parent_id).to eq(food.id)
    end

    it 'returns 422 when the parent is a child account or missing' do
      [ eating_out.id, 999_999_999 ].each do |parent_id|
        post_account(name: '居酒屋', parent_id: parent_id)

        expect(response).to have_http_status(:unprocessable_content)
        expect(body['error']).to eq('invalid_parent')
      end
    end

    it 'returns 422 for a duplicate name under the same parent, but allows it under another parent' do
      post_account(name: '外食費', parent_id: food.id)
      expect(response).to have_http_status(:unprocessable_content)
      expect(body).to include('error' => 'duplicate_account_name')
      expect(body['next_token']).to be_present

      post_account(name: '外食費', parent_id: transport.id)
      expect(response).to have_http_status(:created)
    end

    it 'returns 422 with errors for a blank name' do
      post_account(name: '')

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['errors']).to eq([ "Name can't be blank" ])
    end
  end

  describe 'PUT /expense-accounts/:id' do
    it 'renames an account in use' do
      spend_on(eating_out)

      put_account(eating_out, name: '外食', parent_id: food.id)

      expect(response).to have_http_status(:ok)
      expect(eating_out.reload.name).to eq('外食')
    end

    it 'moves an unused account under another parent, or to the top level' do
      put_account(eating_out, name: '外食費', parent_id: transport.id)
      expect(response).to have_http_status(:ok)
      expect(eating_out.reload.parent_id).to eq(transport.id)

      put_account(eating_out, name: '外食費', parent_id: nil)
      expect(response).to have_http_status(:ok)
      expect(eating_out.reload.parent_id).to be_nil
    end

    it 'returns 422 when moving an account in use' do
      spend_on(eating_out)

      put_account(eating_out, name: '外食費', parent_id: transport.id)

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('expense_account_in_use')
      expect(eating_out.reload.parent_id).to eq(food.id)
    end

    it 'returns 422 when giving a parent to an account with children' do
      put_account(food, name: '食費', parent_id: transport.id)

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('expense_account_has_children')
    end

    it 'returns 422 when making an account its own parent' do
      put_account(transport, name: '交通費', parent_id: transport.id)

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('invalid_parent')
    end

    it "returns 404 for another user's own account" do
      other_account = create(:expense_account, name: 'other-user-expense', user: create(:user))

      put_account(other_account, name: 'x', parent_id: nil)

      expect(response).to have_http_status(:not_found)
      expect(body['error']).to eq('expense_account_not_found')
    end
  end

  describe 'DELETE /expense-accounts/:id' do
    it 'returns 204 and deletes an unused account without children' do
      delete "/expense-accounts/#{transport.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(response.headers['X-Next-Token']).to be_present
      expect(ExpenseAccount.exists?(transport.id)).to be(false)
    end

    it 'returns 422 for an account in use' do
      spend_on(eating_out)

      delete "/expense-accounts/#{eating_out.id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('expense_account_in_use')
    end

    it 'returns 422 for an account with children' do
      delete "/expense-accounts/#{food.id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('expense_account_has_children')
      expect(ExpenseAccount.exists?(food.id)).to be(true)
    end
  end

  it 'returns 401 without a token' do
    post '/expense-accounts', params: { name: 'x' }.to_json, headers: { 'Content-Type' => 'application/json' }

    expect(response).to have_http_status(:unauthorized)
  end
end
