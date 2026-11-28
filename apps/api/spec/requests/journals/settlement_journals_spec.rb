# frozen_string_literal: true

require 'rails_helper'

# 立て替えた分の精算（M19）: 立替金の口座（種別 6）、お買い物で立て替える、振替で立替金に入れる、
# 精算（POST /settlement-journals、PUT /settlement-journals/:id）、仕訳一覧の科目の合計
RSpec.describe 'Settlement journals', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) do
    {
      'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}",
      'Content-Type' => 'application/json'
    }
  end

  let!(:eating_out) { create(:expense_account, :eating_out, :common) }
  let!(:transportation) { create(:expense_account, :transportation, :common) }
  let!(:misc_income) { create(:revenue_account, :common, name: '雑収入') }
  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:paypay) { create(:asset_account, :suica, name: 'PayPay', user: user) }
  let!(:pasmo) { create(:asset_account, :pasmo, user: user) }
  let!(:tanaka) { create(:asset_account, :advance_tanaka, user: user) }
  let!(:suzuki) { create(:asset_account, :advance_suzuki, user: user) }
  let!(:company) { create(:asset_account, :advance_company, user: user) }
  let!(:tcard) { create(:liability_account, :tcard, user: user) }

  before { create(:credit_card, :tcard, user: user, liability_account: tcard, bank_account: bank) }

  let(:card_payment) { { element_type: 2, payment_method_type: 3, account_id: tcard.id } }

  def body
    JSON.parse(response.body)
  end

  def balances(date = '2026-11-30')
    get '/account-balances', params: { date: date }, headers: headers
    JSON.parse(response.body)['assets'].to_h { |a| [ a['account_id'], a['balance'] ] }
  end

  def monthly_total(month = '2026-11')
    get '/monthly-expenses', params: { month: month }, headers: headers
    JSON.parse(response.body).values_at('total', 'income_total')
  end

  # 飲み会 32,000 円をカードで払い、田中さん・鈴木さんの分 10,000 円ずつを立て替えた
  def party_entry(own: 12_000, advances: { tanaka => 10_000, suzuki => 10_000 })
    debits = []
    debits << { element_type: 5, account_id: eating_out.id, item_name: '飲み会', amount: own } if own.positive?
    advances.each { |account, amount| debits << { element_type: 1, account_id: account.id, item_name: '立替', amount: amount } }

    {
      date: '2026-11-05',
      store_name: '居酒屋',
      debits: debits,
      credits: [ card_payment.merge(amount: own + advances.values.sum) ]
    }
  end

  def post_entry(entry)
    post '/journal-entries', params: entry.to_json, headers: headers
  end

  def settle(overrides = {})
    params = {
      journal_date: '2026-11-10', receivable_account_id: tanaka.id, settled_amount: 10_000,
      received_amount: 10_000, to_account_id: cash.id
    }.merge(overrides)

    post '/settlement-journals', params: params.to_json, headers: headers
  end

  def entries(journal_id)
    journal = Journal.find(journal_id)

    [
      journal.debits.sort_by(&:id).map { |d| [ d.element_type.to_i, d.account_id, d.amount.to_i ] },
      journal.credits.sort_by(&:id).map { |c| [ c.element_type.to_i, c.payment_method_type, c.account_id, c.amount.to_i ] }
    ]
  end

  describe 'paying for others in a purchase' do
    it 'counts only my share as an expense and leaves the others as receivables' do
      post_entry(party_entry)

      expect(response).to have_http_status(:created)
      journal_id = body['journal_id']
      expect(monthly_total).to eq([ 12_000, 0 ])
      expect(balances.values_at(tanaka.id, suzuki.id)).to eq([ 10_000, 10_000 ])
      # カードの引き落としは全額
      expect(Journal.find(journal_id).credits.sole.amount.to_i).to eq(32_000)
      expect(DirectDebitJournal.find_by!(original_id: journal_id)).to be_present
    end

    it 'registers and edits a purchase paid entirely for the company' do
      post_entry(party_entry(own: 0, advances: { company => 3_000 }))
      expect(response).to have_http_status(:created)

      put "/journal-entries/#{body['journal_id']}",
          params: party_entry(own: 1_000, advances: { company => 2_000 }).to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(entries(body['journal_id'])[0]).to eq([ [ 5, eating_out.id, 1_000 ], [ 1, company.id, 2_000 ] ])
    end

    it 'shows the asset type of the receivable lines in the journal' do
      post_entry(party_entry)

      get "/journals/#{body['journal_id']}", headers: headers
      expect(body['debits'].map { |d| d['asset_type'] }).to eq([ nil, 6, 6 ])
    end

    it 'returns 422 when the edit debits an asset that is not a receivable' do
      post_entry(party_entry)
      journal_id = body['journal_id']

      put "/journal-entries/#{journal_id}",
          params: party_entry(own: 12_000, advances: { cash => 20_000 }).to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('expense_debits_required')
      expect(Journal.exists?(journal_id)).to be(true)
    end
  end

  describe 'transfers' do
    def transfer(from:, to:, amount: 420)
      post '/transfer-journals',
           params: { journal_date: '2026-11-06', from_type: 'asset', from_account_id: from.id, to_account_id: to.id,
                     amount: amount, description: '交通費（仕事）' }.to_json,
           headers: headers
    end

    it 'moves a business ride from PASMO into the company receivable, outside the expenses' do
      transfer(from: pasmo, to: company)

      expect(response).to have_http_status(:created)
      expect(balances.values_at(pasmo.id, company.id)).to eq([ -420, 420 ])
      expect(monthly_total).to eq([ 0, 0 ])
    end

    it 'returns 422 for a transfer out of a receivable' do
      transfer(from: company, to: bank)

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('receivable_requires_settlement')
      expect(Journal.count).to eq(0)
    end
  end

  describe 'POST /settlement-journals' do
    before { post_entry(party_entry) }

    it 'settles the exact amount received in cash' do
      settle

      expect(response).to have_http_status(:created)
      expect(body['next_token']).to be_present
      expect(Journal.find(body['journal_id']).store_name).to eq('精算 立替金 田中')
      expect(entries(body['journal_id'])).to eq([
        [ [ 1, cash.id, 10_000 ] ],
        [ [ 1, 6, tanaka.id, 10_000 ] ]
      ])
      expect(balances.values_at(tanaka.id, cash.id)).to eq([ 0, 10_000 ])
      expect(monthly_total).to eq([ 12_000, 0 ])
    end

    it 'settles with PayPay and a description' do
      settle(receivable_account_id: suzuki.id, to_account_id: paypay.id, description: '鈴木さん PayPay')

      expect(Journal.find(body['journal_id']).store_name).to eq('鈴木さん PayPay')
      expect(balances.values_at(suzuki.id, paypay.id)).to eq([ 0, 10_000 ])
    end

    it 'records a shortfall as an expense' do
      settle(received_amount: 9_500, difference_account_id: transportation.id)

      expect(response).to have_http_status(:created)
      expect(entries(body['journal_id'])).to eq([
        [ [ 1, cash.id, 9_500 ], [ 5, transportation.id, 500 ] ],
        [ [ 1, 6, tanaka.id, 10_000 ] ]
      ])
      expect(monthly_total).to eq([ 12_500, 0 ])
    end

    it 'records an overpayment as a revenue' do
      settle(received_amount: 10_200, difference_account_id: misc_income.id)

      expect(entries(body['journal_id'])).to eq([
        [ [ 1, cash.id, 10_200 ] ],
        [ [ 1, 6, tanaka.id, 10_000 ], [ 4, 0, misc_income.id, 200 ] ]
      ])
      expect(monthly_total).to eq([ 12_000, 200 ])
    end

    it 'writes the whole amount off as an expense when nothing is received' do
      settle(received_amount: 0, to_account_id: nil, difference_account_id: eating_out.id)

      expect(response).to have_http_status(:created)
      expect(entries(body['journal_id'])).to eq([
        [ [ 5, eating_out.id, 10_000 ] ],
        [ [ 1, 6, tanaka.id, 10_000 ] ]
      ])
      expect(balances[tanaka.id]).to eq(0)
    end

    it 'ignores a difference account when the amounts match' do
      settle(difference_account_id: misc_income.id)

      expect(entries(body['journal_id'])[1]).to eq([ [ 1, 6, tanaka.id, 10_000 ] ])
    end

    it 'returns 404 for an account or difference account of another user or of the wrong type' do
      other = create(:user)

      settle(receivable_account_id: create(:asset_account, :advance_tanaka, user: other).id)
      expect(response).to have_http_status(:not_found)
      expect(body).to include('error' => 'receivable_account_not_found')
      expect(body['next_token']).to be_present

      settle(receivable_account_id: cash.id)
      expect(body['error']).to eq('receivable_account_not_found')

      settle(to_account_id: suzuki.id)
      expect(body['error']).to eq('to_account_not_found')

      settle(to_account_id: create(:asset_account, :cash, user: other).id)
      expect(body['error']).to eq('to_account_not_found')

      # 少なく受け取ったら費用科目、多く受け取ったら収益科目
      settle(received_amount: 9_000, difference_account_id: misc_income.id)
      expect(body['error']).to eq('difference_account_not_found')

      settle(received_amount: 11_000, difference_account_id: eating_out.id)
      expect(response).to have_http_status(:not_found)
      expect(body['error']).to eq('difference_account_not_found')
      expect(Journal.count).to eq(2)
    end

    it 'returns 422 with errors for an invalid request' do
      post '/settlement-journals', params: { settled_amount: 0, received_amount: -1 }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['errors']).to contain_exactly(
        "Journal date can't be blank",
        'Settled amount must be an integer between 1 and 2147483647',
        'Received amount must be an integer between 0 and 2147483647',
        'Receivable account must be a positive integer'
      )

      settle(to_account_id: nil, received_amount: 9_000)
      expect(body['errors']).to contain_exactly(
        'To account must be a positive integer when received_amount is positive',
        'Difference account must be a positive integer when the amounts differ'
      )
    end

    it 'returns 401 without a token' do
      post '/settlement-journals', params: {}.to_json, headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /settlement-journals/:id' do
    before { post_entry(party_entry) }

    it 'replaces the settlement with a new id' do
      settle
      journal_id = body['journal_id']

      put "/settlement-journals/#{journal_id}",
          params: { journal_date: '2026-11-12', receivable_account_id: tanaka.id, settled_amount: 10_000,
                    received_amount: 8_000, to_account_id: paypay.id, difference_account_id: eating_out.id }.to_json,
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(Journal.exists?(journal_id)).to be(false)
      expect(entries(body['journal_id'])[0]).to eq([ [ 1, paypay.id, 8_000 ], [ 5, eating_out.id, 2_000 ] ])
    end

    it 'returns 422 for a journal that is not a settlement' do
      purchase_id = Journal.order(:id).first.id

      put "/settlement-journals/#{purchase_id}",
          params: { journal_date: '2026-11-12', receivable_account_id: tanaka.id, settled_amount: 1,
                    received_amount: 1, to_account_id: cash.id }.to_json,
          headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('journal_not_editable')
    end

    it 'cannot be edited as a transfer or a purchase' do
      settle
      exact_id = body['journal_id']
      settle(receivable_account_id: suzuki.id, received_amount: 0, to_account_id: nil, difference_account_id: eating_out.id)
      write_off_id = body['journal_id']

      put "/transfer-journals/#{exact_id}",
          params: { journal_date: '2026-11-10', from_type: 'asset', from_account_id: bank.id, to_account_id: cash.id,
                    amount: 10_000 }.to_json,
          headers: headers
      expect(body['error']).to eq('journal_not_editable')

      put "/journal-entries/#{write_off_id}", params: party_entry.to_json, headers: headers
      expect(body['error']).to eq('journal_not_editable')
      expect(Journal.exists?(exact_id) && Journal.exists?(write_off_id)).to be(true)
    end
  end

  describe 'GET /journals with an account' do
    it 'returns the debit and credit totals of the account over all matching journals' do
      post_entry(party_entry(own: 0, advances: { company => 1_200 }))
      post '/transfer-journals',
           params: { journal_date: '2026-11-06', from_type: 'asset', from_account_id: pasmo.id,
                     to_account_id: company.id, amount: 420 }.to_json,
           headers: headers
      settle(journal_date: '2026-12-10', receivable_account_id: company.id, settled_amount: 1_620,
             received_amount: 1_600, to_account_id: bank.id, difference_account_id: transportation.id)

      get '/journals', params: { from: '2026-11-01', to: '2026-11-30', element_type: 1, account_id: company.id },
                       headers: headers
      expect(body['account_totals']).to eq('debit_total' => 1_620, 'credit_total' => 0)

      get '/journals', params: { element_type: 1, account_id: company.id }, headers: headers
      expect(body['account_totals']).to eq('debit_total' => 1_620, 'credit_total' => 1_620)
      expect(balances('2026-12-31')[company.id]).to eq(0)

      get '/journals', headers: headers
      expect(body['account_totals']).to be_nil
    end
  end
end
