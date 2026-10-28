# frozen_string_literal: true

#
# spec/requests/journals/asset_opening_journals_flow_spec.rb
#
# asset_opening_journals_spec.rb は認証・Form・Service をスタブしているため、
# 実際の DB 関数まで通した結果（重複登録の 409 など）をここで確認する。

require 'rails_helper'

RSpec.describe 'POST /asset-opening-journals (without stubs)', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) do
    {
      'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}",
      'Content-Type' => 'application/json'
    }
  end

  let!(:asset_account) { create(:asset_account, :cash, user: user) }

  before { create(:equity_account, :original_deposit, user: user) }

  def post_opening(account, amount: 100_000)
    post '/asset-opening-journals',
         params: { journal_date: '2026-02-01', asset_type: 1, asset_account_id: account.id, amount: amount }.to_json,
         headers: headers
  end

  it 'returns 201 for the first registration of an account' do
    post_opening(asset_account)

    expect(response).to have_http_status(:created)
    expect(JSON.parse(response.body)['journal_id']).to be_present
  end

  it 'returns 409 when the opening balance of the account is registered again' do
    post_opening(asset_account)

    expect { post_opening(asset_account, amount: 5_000) }.not_to change(Journal, :count)

    expect(response).to have_http_status(:conflict)

    body = JSON.parse(response.body)
    expect(body['error']).to eq('opening_asset_already_exists')
    expect(body['next_token']).to be_present
  end

  it "returns 404 and creates nothing for another user's account" do
    other_users_account = create(:asset_account, :suica, user: create(:user))

    expect { post_opening(other_users_account) }.not_to change(Journal, :count)

    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)['error']).to eq('asset_account_not_found')
  end

  it 'returns 404 for an account that does not exist' do
    post '/asset-opening-journals',
         params: { journal_date: '2026-02-01', asset_type: 1, asset_account_id: 0, amount: 1_000 }.to_json,
         headers: headers

    expect(response).to have_http_status(:not_found)
  end

  it "does not use another user's equity account" do
    other_equity = create(:equity_account, :original_deposit, user: create(:user))

    post_opening(asset_account)

    credit = Journal.find(JSON.parse(response.body)['journal_id']).credits.first
    expect(credit.account_id).not_to eq(other_equity.id)
  end

  it 'uses the common equity account when the user has none of their own' do
    EquityAccount.where(user: user).delete_all
    common_equity = create(:equity_account, :original_deposit, :common)

    post_opening(asset_account)

    expect(response).to have_http_status(:created)
    credit = Journal.find(JSON.parse(response.body)['journal_id']).credits.first
    expect(credit.account_id).to eq(common_equity.id)
  end

  it 'allows an opening balance for another account' do
    post_opening(asset_account)
    post_opening(create(:asset_account, :suica, user: user))

    expect(response).to have_http_status(:created)
  end
end
