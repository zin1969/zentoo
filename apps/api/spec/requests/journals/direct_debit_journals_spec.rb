# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PUT /direct-debit-journals/:id', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) do
    {
      'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}",
      'Content-Type' => 'application/json'
    }
  end

  let!(:expense) { create(:expense_account, :eating_out, :common) }
  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:tcard) { create(:liability_account, :tcard, user: user) }

  before { create(:credit_card, :tcard, user: user, liability_account: tcard, bank_account: bank) }

  def register(credit:, owner: user)
    Journals::InsertJournalEntry.new.insert_journal_entry!(
      journal_data: {
        date: '2026-10-09',
        user_id: owner.id,
        store_name: 'Aquavit 001',
        debits: [ { element_type: 5, account_id: expense.id, item_name: 'バー', amount: 3_300 } ],
        credits: [ credit.merge(amount: 3_300) ]
      }
    )
  end

  let!(:journal_id) { register(credit: { element_type: 2, payment_method_type: 3, account_id: tcard.id }) }
  let(:direct_debit_id) { DirectDebitJournal.find_by!(original_id: journal_id).direct_debit_id }

  def put_date(id, payment_date)
    put "/direct-debit-journals/#{id}", params: { payment_date: payment_date }.to_json, headers: headers
  end

  def listed(id)
    get '/journals', headers: headers
    JSON.parse(response.body)['journals'].find { |journal| journal['id'] == id }
  end

  it 'returns 200 with the journal id and a next token, and moves the direct debit' do
    expect(listed(direct_debit_id)).to include('journal_date' => '2026-10-27', 'payment_date_overridden' => false)

    put_date(direct_debit_id, '2026-11-27')

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['journal_id']).to eq(direct_debit_id)
    expect(body['next_token']).to be_present

    expect(listed(direct_debit_id)).to include('journal_date' => '2026-11-27', 'payment_date_overridden' => true)
    expect(listed(journal_id)).to include('journal_date' => '2026-10-09', 'payment_date_overridden' => false)
  end

  it 'moves the bank withdrawal in the balances' do
    put_date(direct_debit_id, '2026-11-27')

    get '/account-balances', params: { date: '2026-10-31' }, headers: headers
    liabilities = JSON.parse(response.body)['liabilities'].to_h { |l| [ l['account_id'], l['balance'] ] }
    expect(liabilities[tcard.id]).to eq(3_300)
  end

  it "returns 404 for another user's journal" do
    other_headers = headers.merge('Authorization' => "Bearer #{TokenManager.new.issue_next_token(create(:user))}")

    put "/direct-debit-journals/#{direct_debit_id}", params: { payment_date: '2026-11-27' }.to_json, headers: other_headers

    expect(response).to have_http_status(:not_found)
    body = JSON.parse(response.body)
    expect(body['error']).to eq('journal_not_found')
    expect(body['next_token']).to be_present
  end

  it 'returns 422 for a journal that is not a direct debit journal' do
    put_date(journal_id, '2026-11-27')

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)['error']).to eq('not_direct_debit_journal')
  end

  it 'returns 422 for a date before the purchase date' do
    put_date(direct_debit_id, '2026-10-08')

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)['error']).to eq('payment_date_before_journal_date')
    expect(Journal.find(direct_debit_id).journal_dt).to eq(Date.new(2026, 10, 27))
  end

  it 'returns 422 with errors for a missing or invalid date' do
    put_date(direct_debit_id, 'not-a-date')

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)['errors']).to eq([ "Payment date can't be blank" ])
  end

  it 'returns 401 without a token' do
    put "/direct-debit-journals/#{direct_debit_id}", params: { payment_date: '2026-11-27' }.to_json,
                                                     headers: { 'Content-Type' => 'application/json' }

    expect(response).to have_http_status(:unauthorized)
  end
end
