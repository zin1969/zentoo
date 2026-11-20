# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /journals/:id', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) { { 'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}" } }

  let!(:expense) { create(:expense_account, :eating_out, :common) }
  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:tcard) { create(:liability_account, :tcard, user: user) }

  before { create(:credit_card, :tcard, user: user, liability_account: tcard, bank_account: bank) }

  def register(credit:, owner: user)
    Journals::InsertJournalEntry.new.insert_journal_entry!(
      journal_data: {
        date: '2026-10-20',
        user_id: owner.id,
        store_name: 'Aquavit 001',
        debits: [ { element_type: 5, account_id: expense.id, item_name: 'バー', amount: 3_300 } ],
        credits: [ credit.merge(amount: 3_300) ]
      }
    )
  end

  it 'returns the journal in the same shape as the journal list, with a next token header' do
    journal_id = register(credit: { element_type: 2, payment_method_type: 3, account_id: tcard.id })

    get "/journals/#{journal_id}", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.headers['X-Next-Token']).to be_present

    body = JSON.parse(response.body)
    get '/journals', headers: headers
    expect(body).to eq(JSON.parse(response.body)['journals'].find { |journal| journal['id'] == journal_id })
    expect(body['direct_debit_journal_id']).to be_present
  end

  it "returns 404 for another user's journal or a missing one" do
    other = create(:user)
    other_cash = create(:asset_account, :cash, user: other)
    journal_id = register(credit: { element_type: 1, payment_method_type: 1, account_id: other_cash.id }, owner: other)

    get "/journals/#{journal_id}", headers: headers
    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)['error']).to eq('journal_not_found')

    get '/journals/99999999999', headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it 'returns 401 without a token' do
    get "/journals/#{register(credit: { element_type: 1, payment_method_type: 1, account_id: cash.id })}"

    expect(response).to have_http_status(:unauthorized)
  end
end
