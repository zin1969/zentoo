# frozen_string_literal: true

require 'rails_helper'

# タグの集計（GET /tag-reports/:id、GET /tag-reports/:id/items）。DB 関数 get_tag_monthly_totals・get_tag_items を通す
RSpec.describe 'Tag reports', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) { { 'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}" } }

  let!(:books) { create(:expense_account, :common, name: '書籍') }
  let!(:seminars) { create(:expense_account, :common, name: 'セミナー') }
  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:study) { create(:tag, :study, user: user) }
  let!(:fun) { create(:tag, :fun, user: user) }

  def buy(date:, lines:, owner: user, credit_account: cash)
    Journals::InsertJournalEntry.new.insert_journal_entry!(
      journal_data: {
        date: date, user_id: owner.id, store_name: '本屋',
        debits: lines.map do |account, item, amount, tag_ids|
          { element_type: 5, account_id: account.id, item_name: item, amount: amount, tag_ids: tag_ids }
        end,
        credits: [ { element_type: 1, payment_method_type: 1, account_id: credit_account.id,
                     amount: lines.sum { |line| line[2] } } ]
      }
    )
  end

  def body
    JSON.parse(response.body)
  end

  before do
    # 1 つの買い物の中で、勉強の明細と娯楽の明細が混ざる
    buy(date: '2026-01-10', lines: [ [ books, '参考書', 2_000, [ study.id ] ], [ books, '漫画', 500, [ fun.id ] ] ])
    buy(date: '2026-01-25', lines: [ [ seminars, 'Rails 勉強会', 1_000, [ study.id ] ] ])
    buy(date: '2026-03-31', lines: [ [ books, '技術書', 3_000, [ study.id, fun.id ] ] ])
    buy(date: '2025-12-31', lines: [ [ books, '去年の本', 9_999, [ study.id ] ] ])
    buy(date: '2026-02-01', lines: [ [ books, 'タグなし', 7_777, [] ] ])
  end

  describe 'GET /tag-reports/:id' do
    it 'returns the 12 monthly totals and the yearly total of the tag, with a next token header' do
      get "/tag-reports/#{study.id}", params: { year: 2026 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.headers['X-Next-Token']).to be_present
      expect(body).to include('tag' => { 'id' => study.id, 'name' => '勉強' }, 'year' => 2026, 'total' => 6_000)
      expect(body['months'].map { |m| [ m['month'], m['amount'] ] })
        .to eq([ [ 1, 3_000 ], [ 2, 0 ], [ 3, 3_000 ] ] + (4..12).map { |m| [ m, 0 ] })
    end

    it 'counts a line with several tags in each of them' do
      get "/tag-reports/#{fun.id}", params: { year: 2026 }, headers: headers

      expect(body['total']).to eq(3_500)
    end

    it 'defaults to this year in Japan time' do
      travel_to(Time.utc(2025, 12, 31, 15, 0)) do
        get "/tag-reports/#{study.id}", headers: headers
      end

      expect(body).to include('year' => 2026, 'total' => 6_000)
    end

    it "returns 404 for another user's tag" do
      get "/tag-reports/#{create(:tag, :study, user: create(:user)).id}", headers: headers

      expect(response).to have_http_status(:not_found)
      expect(body['error']).to eq('tag_not_found')
    end

    it 'returns 422 for an invalid year' do
      get "/tag-reports/#{study.id}", params: { year: '26' }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['errors']).to eq([ 'Year must be a year between 2000 and 2100' ])
    end
  end

  describe 'GET /tag-reports/:id/items' do
    it 'returns the tagged lines of the month in date order, with the total' do
      get "/tag-reports/#{study.id}/items", params: { month: '2026-01' }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(body).to include('tag' => { 'id' => study.id, 'name' => '勉強' }, 'month' => '2026-01', 'total' => 3_000)
      expect(body['items'].map { |i| i.slice('journal_date', 'store_name', 'item_name', 'account_name', 'amount') }).to eq([
        { 'journal_date' => '2026-01-10', 'store_name' => '本屋', 'item_name' => '参考書', 'account_name' => '書籍', 'amount' => 2_000 },
        { 'journal_date' => '2026-01-25', 'store_name' => '本屋', 'item_name' => 'Rails 勉強会', 'account_name' => 'セミナー', 'amount' => 1_000 }
      ])
      expect(body['items'].first['journal_id']).to be_present
    end

    it 'includes the last day of the month and returns an empty list for a month without lines' do
      get "/tag-reports/#{study.id}/items", params: { month: '2026-03' }, headers: headers
      expect(body['items'].map { |i| i['item_name'] }).to eq([ '技術書' ])

      get "/tag-reports/#{study.id}/items", params: { month: '2026-02' }, headers: headers
      expect(body).to include('total' => 0, 'items' => [])
    end

    it 'returns 422 for an invalid month' do
      get "/tag-reports/#{study.id}/items", params: { month: '2026-13' }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['errors']).to eq([ 'Month must be a month (YYYY-MM)' ])
    end
  end

  it 'returns 401 without a token' do
    get "/tag-reports/#{study.id}"

    expect(response).to have_http_status(:unauthorized)
  end
end
