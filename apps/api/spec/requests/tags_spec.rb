# frozen_string_literal: true

require 'rails_helper'

# タグの一覧・追加・名前の変更・削除（/tags）と、仕訳一覧の明細のタグ
RSpec.describe 'Tags', type: :request do
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
  let!(:fun) { create(:tag, :fun, user: user) }

  def body
    JSON.parse(response.body)
  end

  def buy(tag_ids)
    Journals::InsertJournalEntry.new.insert_journal_entry!(
      journal_data: {
        date: '2026-11-05', user_id: user.id, store_name: '本屋',
        debits: [ { element_type: 5, account_id: books.id, item_name: '参考書', amount: 2_000, tag_ids: tag_ids } ],
        credits: [ { element_type: 1, payment_method_type: 1, account_id: cash.id, amount: 2_000 } ]
      }
    )
  end

  describe 'GET /tags' do
    it "lists the user's tags in the order they were created, with how many lines use them" do
      buy([ study.id ])
      buy([ study.id, fun.id ])
      create(:tag, name: 'other-user-tag', user: create(:user))

      get '/tags', headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.headers['X-Next-Token']).to be_present
      expect(body).to eq([
        { 'id' => study.id, 'name' => '勉強', 'usage_count' => 2 },
        { 'id' => fun.id, 'name' => '娯楽', 'usage_count' => 1 }
      ])
    end
  end

  describe 'POST /tags' do
    it 'returns 201 with the new tag and a next token' do
      post '/tags', params: { name: ' 一人飲み ' }.to_json, headers: headers

      expect(response).to have_http_status(:created)
      expect(body).to include('name' => '一人飲み')
      expect(body['next_token']).to be_present
      expect(Tag.find(body['id']).user_id).to eq(user.id)
    end

    it "returns 422 for a duplicate name, but allows another user's name" do
      post '/tags', params: { name: '勉強' }.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('duplicate_tag_name')

      create(:tag, name: '旅行', user: create(:user))
      post '/tags', params: { name: '旅行' }.to_json, headers: headers
      expect(response).to have_http_status(:created)
    end

    it 'returns 422 with errors for a blank or too long name' do
      post '/tags', params: { name: 'x' * 31 }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['errors']).to eq([ 'Name is too long (maximum is 30 characters)' ])
    end
  end

  describe 'PUT /tags/:id' do
    it 'renames a tag, which shows up on the lines that use it' do
      journal_id = buy([ study.id ])

      put "/tags/#{study.id}", params: { name: '学習' }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      get "/journals/#{journal_id}", headers: headers
      expect(body['debits'].sole['tags']).to eq([ { 'id' => study.id, 'name' => '学習' } ])
    end

    it "returns 404 for another user's tag" do
      other = create(:tag, name: 'other', user: create(:user))

      put "/tags/#{other.id}", params: { name: 'x' }.to_json, headers: headers

      expect(response).to have_http_status(:not_found)
      expect(body['error']).to eq('tag_not_found')
    end
  end

  describe 'DELETE /tags/:id' do
    it 'deletes a tag in use, removing it from the lines but keeping the lines' do
      journal_id = buy([ study.id, fun.id ])

      delete "/tags/#{study.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(Tag.exists?(study.id)).to be(false)

      get '/journals', headers: headers
      listed = body['journals'].find { |journal| journal['id'] == journal_id }
      expect(listed['debits'].sole['tags']).to eq([ { 'id' => fun.id, 'name' => '娯楽' } ])
    end
  end

  it 'returns 401 without a token' do
    get '/tags'

    expect(response).to have_http_status(:unauthorized)
  end
end
