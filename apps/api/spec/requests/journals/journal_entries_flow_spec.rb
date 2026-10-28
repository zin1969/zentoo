# frozen_string_literal: true

#
# spec/requests/journals/journal_entries_flow_spec.rb
#
# journal_entries_spec.rb は認証・Form・Service をスタブしているため、
# 実際の DB 関数まで通した結果（共通科目・他人の科目の扱い）をここで確認する。

require 'rails_helper'

RSpec.describe 'POST /journal-entries (without stubs)', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) do
    {
      'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}",
      'Content-Type' => 'application/json'
    }
  end

  let!(:cash) { create(:asset_account, :cash, user: user) }
  let(:common_expense) { create(:expense_account, :food, :common) }

  def post_entry(expense:, asset:)
    post '/journal-entries',
         params: {
           date: '2026-07-19',
           user_id: 0, # Web クライアントと同じダミー値。controller が認証済みユーザーの ID で上書きする
           store_name: 'ピザーラ',
           debits: [ { element_type: 5, account_id: expense.id, amount: 1_000, item_name: 'ピザ' } ],
           credits: [ { element_type: 1, payment_method_type: 1, account_id: asset.id, amount: 1_000 } ]
         }.to_json,
         headers: headers
  end

  it 'returns 201 for a common expense account and own asset account' do
    expect { post_entry(expense: common_expense, asset: cash) }.to change(Journal, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(Journal.last.user_id).to eq(user.id)
  end

  it "returns 404 and creates nothing for another user's expense account" do
    other_expense = create(:expense_account, :food, user: create(:user))

    expect { post_entry(expense: other_expense, asset: cash) }.not_to change(Journal, :count)

    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)['error']).to eq('account_not_found')
  end

  it "returns 404 and creates nothing for another user's asset account" do
    other_asset = create(:asset_account, :suica, user: create(:user))

    expect { post_entry(expense: common_expense, asset: other_asset) }.not_to change(Journal, :count)

    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)['next_token']).to be_present
  end
end
