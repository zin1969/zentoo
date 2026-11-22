# frozen_string_literal: true

require 'rails_helper'

# 収益科目の一覧・追加・変更・削除（/revenue-accounts）。仕組みは費用科目と共通（TwoLevelAccountsActions）
RSpec.describe 'Managing revenue accounts', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) do
    {
      'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}",
      'Content-Type' => 'application/json'
    }
  end

  let!(:salary) { create(:revenue_account, :salary, :common) }
  let!(:base_pay) { create(:revenue_account, :common, name: '基本給', parent: salary) }

  def body
    JSON.parse(response.body)
  end

  it 'lists the common accounts and the own accounts with their parent' do
    create(:revenue_account, name: 'other-user-revenue', user: create(:user))

    get '/revenue-accounts', headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.headers['X-Next-Token']).to be_present
    expect(body).to eq([
      { 'id' => salary.id, 'name' => '給与', 'parent_id' => nil, 'in_use' => false, 'has_children' => true },
      { 'id' => base_pay.id, 'name' => '基本給', 'parent_id' => salary.id, 'in_use' => false, 'has_children' => false }
    ])
  end

  it 'creates a common top-level account and a child account' do
    post '/revenue-accounts', params: { name: ' 雑収入 ' }.to_json, headers: headers
    expect(response).to have_http_status(:created)
    expect(body['next_token']).to be_present
    expect(RevenueAccount.find(body['id']).attributes.values_at('user_id', 'name', 'parent_id')).to eq([ nil, '雑収入', nil ])

    post '/revenue-accounts', params: { name: '残業代', parent_id: salary.id }.to_json, headers: headers
    expect(response).to have_http_status(:created)
    expect(RevenueAccount.find(body['id']).parent_id).to eq(salary.id)
  end

  it 'returns 422 for a duplicate name or a child account as the parent' do
    post '/revenue-accounts', params: { name: '基本給', parent_id: salary.id }.to_json, headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(body['error']).to eq('duplicate_account_name')

    post '/revenue-accounts', params: { name: '手当', parent_id: base_pay.id }.to_json, headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(body['error']).to eq('invalid_parent')
  end

  it 'renames an account and moves an unused child to the top level' do
    put "/revenue-accounts/#{base_pay.id}", params: { name: '月給', parent_id: nil }.to_json, headers: headers

    expect(response).to have_http_status(:ok)
    expect(base_pay.reload.attributes.values_at('name', 'parent_id')).to eq([ '月給', nil ])
  end

  it 'uses revenue error codes for an account with children or of another user' do
    delete "/revenue-accounts/#{salary.id}", headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(body['error']).to eq('revenue_account_has_children')

    other = create(:revenue_account, name: 'other-user-revenue', user: create(:user))
    put "/revenue-accounts/#{other.id}", params: { name: 'x' }.to_json, headers: headers
    expect(response).to have_http_status(:not_found)
    expect(body['error']).to eq('revenue_account_not_found')
  end

  it 'deletes an unused account without children' do
    delete "/revenue-accounts/#{base_pay.id}", headers: headers

    expect(response).to have_http_status(:no_content)
    expect(RevenueAccount.exists?(base_pay.id)).to be(false)
  end

  it 'returns 401 without a token' do
    get '/revenue-accounts'

    expect(response).to have_http_status(:unauthorized)
  end
end
