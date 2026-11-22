# frozen_string_literal: true

require 'rails_helper'

# お買い物の登録（POST /journal-entries）で、外税の明細の税率・税抜の金額を受け取り、仕訳 1 件の取得で返す
RSpec.describe 'Tax on journal entries', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) do
    {
      'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}",
      'Content-Type' => 'application/json'
    }
  end

  let!(:food) { create(:expense_account, :common, name: '食費') }
  let!(:cash) { create(:asset_account, :cash, user: user) }

  def post_entry(line)
    post '/journal-entries', headers: headers, params: {
      date: '2026-11-05', store_name: 'スーパー',
      debits: [ { element_type: 5, account_id: food.id, item_name: '肉', amount: 1_080 }.merge(line) ],
      credits: [ { element_type: 1, payment_method_type: 1, account_id: cash.id, amount: 1_080 } ]
    }.to_json
  end

  def body
    JSON.parse(response.body)
  end

  it 'saves the tax and returns it on the journal' do
    post_entry(tax_rate: 8, tax_excluded_amount: 1_000)

    expect(response).to have_http_status(:created)
    get "/journals/#{body['journal_id']}", headers: headers
    expect(body['debits'].sole).to include('amount' => 1_080, 'tax_rate' => 8, 'tax_excluded_amount' => 1_000)
  end

  it 'returns 422 when only one of the tax fields is given, or the values are out of range' do
    post_entry(tax_rate: 8)
    expect(response).to have_http_status(:unprocessable_content)
    expect(body['errors'].first).to include('Tax excluded amount must be an integer between 0 and the amount')

    post_entry(tax_rate: 101, tax_excluded_amount: 1_000)
    expect(body['errors'].first).to include('Tax rate must be an integer between 0 and 100')

    post_entry(tax_rate: 8, tax_excluded_amount: 1_100)
    expect(body['errors'].first).to include('Tax excluded amount must be an integer between 0 and the amount')
    expect(Journal.count).to eq(0)
  end
end
