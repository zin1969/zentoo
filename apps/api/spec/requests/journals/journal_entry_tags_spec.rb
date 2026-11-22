# frozen_string_literal: true

require 'rails_helper'

# お買い物の登録（POST /journal-entries）で、明細ごとのタグ（tag_ids）を受け取る
RSpec.describe 'Tags on journal entries', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) do
    {
      'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}",
      'Content-Type' => 'application/json'
    }
  end

  let!(:books) { create(:expense_account, :common, name: '書籍') }
  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:study) { create(:tag, :study, user: user) }

  def post_entry(tag_ids)
    post '/journal-entries', headers: headers, params: {
      date: '2026-11-05', store_name: '本屋',
      debits: [ { element_type: 5, account_id: books.id, item_name: '参考書', amount: 2_000, tag_ids: tag_ids } ],
      credits: [ { element_type: 1, payment_method_type: 1, account_id: cash.id, amount: 2_000 } ]
    }.to_json
  end

  def body
    JSON.parse(response.body)
  end

  it 'saves the tags of the line' do
    post_entry([ study.id ])

    expect(response).to have_http_status(:created)
    expect(Journal.find(body['journal_id']).debits.sole.tags.map(&:name)).to eq([ '勉強' ])
  end

  it "returns 404 for another user's tag" do
    post_entry([ create(:tag, :study, user: create(:user)).id ])

    expect(response).to have_http_status(:not_found)
    expect(body).to include('error' => 'tag_not_found')
    expect(body['next_token']).to be_present
  end

  it 'returns 422 for tag_ids that are not positive integers' do
    post_entry([ 'study' ])

    expect(response).to have_http_status(:unprocessable_content)
    expect(body['errors'].first).to include('Tag ids must be an array of up to 10 positive integers')
  end
end
