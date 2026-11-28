# frozen_string_literal: true

require 'rails_helper'

# 予算と実績（M20）: 予算の設定（/budgets）と、期間ごとの予算と使った額（GET /budget-reports）
RSpec.describe 'Budgets', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) do
    {
      'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}",
      'Content-Type' => 'application/json'
    }
  end

  let!(:food) { create(:expense_account, :food, :common) }
  let!(:eating_out) { create(:expense_account, :eating_out, :common, parent: food) }
  let!(:movie_account) { create(:expense_account, :movie, :common) }
  let!(:utilities) { create(:expense_account, :common, name: '電気代') }
  let!(:insurance) { create(:expense_account, :common, name: '保険料') }
  let!(:alcohol) { create(:tag, user: user, name: 'アルコール') }
  let!(:movie) { create(:tag, user: user, name: '映画') }
  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:advance) { create(:asset_account, :advance_tanaka, user: user) }

  def body
    JSON.parse(response.body)
  end

  def post_budget(params)
    post '/budgets', params: params.to_json, headers: headers
  end

  def food_budget(overrides = {})
    { name: '食費', target_type: 1, expense_account_id: food.id, period_type: 1, amount: 7_000,
      excluded_tag_ids: [ alcohol.id ] }.merge(overrides)
  end

  # 費用の明細（と立て替えた分）を現金で払ったお買い物
  def buy(date, account, amount, tags: [], advance_amount: 0)
    debits = [ { element_type: 5, account_id: account.id, item_name: '品目', amount: amount, tag_ids: tags.map(&:id) } ]
    debits << { element_type: 1, account_id: advance.id, item_name: '立替', amount: advance_amount } if advance_amount.positive?

    Journals::InsertJournalEntry.new.insert_journal_entry!(journal_data: {
      date: date, store_name: '店', user_id: user.id, debits: debits,
      credits: [ { element_type: 1, payment_method_type: 1, account_id: cash.id, amount: amount + advance_amount } ]
    })
  end

  describe 'POST /budgets and GET /budgets' do
    it 'creates a weekly budget of an expense account without a tag and lists it' do
      post_budget(food_budget)

      expect(response).to have_http_status(:created)
      expect(body['next_token']).to be_present

      get '/budgets', headers: headers
      expect(body.sole).to eq(
        'id' => Budget.sole.id, 'name' => '食費', 'target_type' => 1, 'expense_account_id' => food.id, 'tag_id' => nil,
        'target_name' => '食費', 'period_type' => 1, 'amount' => 7_000, 'monthly_amounts' => nil,
        'excluded_tags' => [ { 'id' => alcohol.id, 'name' => 'アルコール' } ]
      )
    end

    it 'creates a monthly budget with an amount for each month and lists budgets by period' do
      post_budget(name: '保険', target_type: 1, expense_account_id: insurance.id, period_type: 3, amount: 60_000)
      amounts = [ 12_000, 11_000, 9_000, 7_000, 6_000, 6_000, 9_000, 10_000, 8_000, 6_000, 8_000, 11_000 ]
      post_budget(name: '電気代', target_type: 1, expense_account_id: utilities.id, period_type: 2, monthly_amounts: amounts)
      post_budget(name: 'アルコール', target_type: 2, tag_id: alcohol.id, period_type: 1, amount: 3_000,
                  expense_account_id: food.id, excluded_tag_ids: [ movie.id ])

      get '/budgets', headers: headers
      expect(body.map { |b| b['name'] }).to eq(%w[アルコール 電気代 保険])
      expect(body[0]).to include('target_type' => 2, 'tag_id' => alcohol.id, 'expense_account_id' => nil,
                                 'target_name' => 'アルコール', 'excluded_tags' => [])
      expect(body[1]).to include('monthly_amounts' => amounts, 'amount' => 0)
    end

    it 'returns 404 for an expense account or tag of another user' do
      other = create(:user)

      post_budget(food_budget(expense_account_id: create(:expense_account, user: other).id))
      expect(response).to have_http_status(:not_found)
      expect(body).to include('error' => 'expense_account_not_found')
      expect(body['next_token']).to be_present

      post_budget(food_budget(excluded_tag_ids: [ create(:tag, user: other).id ]))
      expect(body['error']).to eq('tag_not_found')

      post_budget(name: '他人', target_type: 2, tag_id: create(:tag, user: other).id, period_type: 1, amount: 1)
      expect(body['error']).to eq('tag_not_found')
      expect(Budget.count).to eq(0)
    end

    it 'returns 422 with errors for an invalid request' do
      post_budget(name: ' ', target_type: 3, period_type: 4)
      expect(response).to have_http_status(:unprocessable_content)
      expect(body['errors']).to contain_exactly(
        "Name can't be blank",
        'Target type must be 1 (expense account) or 2 (tag)',
        'Period type must be 1 (week), 2 (month) or 3 (year)'
      )

      post_budget(food_budget(amount: -1, excluded_tag_ids: [ 0 ]))
      expect(body['errors']).to contain_exactly(
        'Amount must be an integer between 0 and 2147483647',
        'Excluded tag ids must be up to 10 positive integers'
      )

      post_budget(food_budget(monthly_amounts: [ 1 ] * 12))
      expect(body['errors']).to eq([ 'Monthly amounts can only be set for a monthly budget' ])

      post_budget(food_budget(period_type: 2, monthly_amounts: [ 1 ] * 11))
      expect(body['errors']).to eq([ 'Monthly amounts must be 12 integers between 0 and 2147483647 (January to December)' ])
    end

    it 'returns 401 without a token' do
      get '/budgets'

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /budgets/:id and DELETE /budgets/:id' do
    let!(:budget_id) do
      post_budget(food_budget)
      body['id']
    end

    it 'updates the budget and replaces the excluded tags' do
      put "/budgets/#{budget_id}", params: food_budget(name: '食費（月）', period_type: 2, amount: 30_000,
                                                       excluded_tag_ids: [ movie.id ]).to_json,
                                   headers: headers

      expect(response).to have_http_status(:ok)
      budget = Budget.find(budget_id)
      expect(budget.attributes.values_at('name', 'period_type', 'amount')).to eq([ '食費（月）', 2, 30_000 ])
      expect(budget.excluded_tags.map(&:id)).to eq([ movie.id ])
    end

    it 'switches the target to a tag and drops the account and excluded tags' do
      put "/budgets/#{budget_id}", params: { name: '映画', target_type: 2, tag_id: movie.id, period_type: 1, amount: 3_000,
                                             expense_account_id: food.id, excluded_tag_ids: [ alcohol.id ] }.to_json,
                                   headers: headers

      budget = Budget.find(budget_id)
      expect(budget.attributes.values_at('expense_account_id', 'tag_id')).to eq([ nil, movie.id ])
      expect(budget.excluded_tags).to be_empty
    end

    it "returns 404 for another user's budget" do
      other_headers = headers.merge('Authorization' => "Bearer #{TokenManager.new.issue_next_token(create(:user))}")

      put "/budgets/#{budget_id}", params: food_budget.to_json, headers: other_headers
      expect(response).to have_http_status(:not_found)
      expect(body['error']).to eq('budget_not_found')

      delete "/budgets/#{budget_id}", headers: other_headers
      expect(response).to have_http_status(:not_found)
    end

    it 'deletes the budget' do
      delete "/budgets/#{budget_id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(Budget.exists?(budget_id)).to be(false)
      expect(BudgetExcludedTag.count).to eq(0)
    end

    it 'keeps the target account and tag from being deleted, and drops a deleted excluded tag' do
      delete "/expense-accounts/#{food.id}", headers: headers
      expect(response).to have_http_status(:unprocessable_content)

      post_budget(name: 'アルコール', target_type: 2, tag_id: alcohol.id, period_type: 1, amount: 3_000)
      delete "/tags/#{alcohol.id}", headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('tag_used_by_budget')

      Budget.find_by!(tag_id: alcohol.id).destroy!
      delete "/tags/#{alcohol.id}", headers: headers
      expect(response).to have_http_status(:no_content)
      expect(Budget.find(budget_id).excluded_tags).to be_empty
    end
  end

  describe 'GET /budget-reports' do
    before do
      post_budget(food_budget)
      post_budget(name: 'アルコール', target_type: 2, tag_id: alcohol.id, period_type: 1, amount: 3_000)
      post_budget(name: '映画', target_type: 2, tag_id: movie.id, period_type: 1, amount: 3_000)
      amounts = [ 12_000, 11_000, 9_000, 7_000, 6_000, 6_000, 9_000, 10_000, 8_000, 6_000, 8_000, 11_000 ]
      post_budget(name: '電気代', target_type: 1, expense_account_id: utilities.id, period_type: 2, monthly_amounts: amounts)
      post_budget(name: '保険', target_type: 1, expense_account_id: insurance.id, period_type: 3, amount: 60_000)

      buy('2026-11-22', food, 500) # 前の週（日曜）
      buy('2026-11-23', food, 1_000) # 今週（月曜）
      buy('2026-11-24', eating_out, 3_000, tags: [ alcohol ]) # 食費からは外し、アルコールに数える
      buy('2026-11-25', eating_out, 2_000) # 子科目も食費
      buy('2026-11-26', food, 1_200, advance_amount: 800) # 立て替えた分は入らない
      buy('2026-11-26', movie_account, 1_800, tags: [ movie ])
      buy('2026-11-30', food, 700) # 次の週
      buy('2026-11-10', utilities, 7_500)
      buy('2026-03-01', insurance, 58_000)
    end

    def report(date)
      get '/budget-reports', params: { date: date }, headers: headers
      body['budgets'].to_h { |b| [ b['name'], b.slice('period_start', 'period_end', 'budget_amount', 'used_amount', 'remaining_amount') ] }
    end

    it 'returns the budget and the used amount of the period containing the date' do
      expect(report('2026-11-26')).to eq(
        '食費' => { 'period_start' => '2026-11-23', 'period_end' => '2026-11-29', 'budget_amount' => 7_000,
                  'used_amount' => 4_200, 'remaining_amount' => 2_800 },
        'アルコール' => { 'period_start' => '2026-11-23', 'period_end' => '2026-11-29', 'budget_amount' => 3_000,
                     'used_amount' => 3_000, 'remaining_amount' => 0 },
        '映画' => { 'period_start' => '2026-11-23', 'period_end' => '2026-11-29', 'budget_amount' => 3_000,
                  'used_amount' => 1_800, 'remaining_amount' => 1_200 },
        '電気代' => { 'period_start' => '2026-11-01', 'period_end' => '2026-11-30', 'budget_amount' => 8_000,
                   'used_amount' => 7_500, 'remaining_amount' => 500 },
        '保険' => { 'period_start' => '2026-01-01', 'period_end' => '2026-12-31', 'budget_amount' => 60_000,
                  'used_amount' => 58_000, 'remaining_amount' => 2_000 }
      )
      expect(body['date']).to eq('2026-11-26')
      expect(body['budgets'].first).to include('name' => '食費', 'target_name' => '食費', 'period_type' => 1)
    end

    it 'uses the week from Monday to Sunday and the amount of the month' do
      expect(report('2026-11-22')['食費']).to include('period_start' => '2026-11-16', 'period_end' => '2026-11-22',
                                                     'used_amount' => 500)
      expect(report('2026-08-15')['電気代']).to include('budget_amount' => 10_000, 'used_amount' => 0,
                                                       'remaining_amount' => 10_000)
    end

    it 'does not count the journals of other users' do
      other = create(:user)
      other_cash = create(:asset_account, :cash, user: other)
      Journals::InsertJournalEntry.new.insert_journal_entry!(journal_data: {
        date: '2026-11-24', store_name: '店', user_id: other.id,
        debits: [ { element_type: 5, account_id: food.id, item_name: '品目', amount: 9_999 } ],
        credits: [ { element_type: 1, payment_method_type: 1, account_id: other_cash.id, amount: 9_999 } ]
      })

      expect(report('2026-11-26')['食費']['used_amount']).to eq(4_200)
    end

    it 'returns 422 for an invalid date and 401 without a token' do
      get '/budget-reports', params: { date: '2026-02-30' }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)

      get '/budget-reports'
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
