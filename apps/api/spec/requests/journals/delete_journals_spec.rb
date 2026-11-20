# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /journals/:id', type: :request do
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

  def cash_payment
    { element_type: 1, payment_method_type: 1, account_id: cash.id }
  end

  def card_payment
    { element_type: 2, payment_method_type: 3, account_id: tcard.id }
  end

  def journal_ids
    get '/journals', headers: headers
    JSON.parse(response.body)['journals'].map { |journal| journal['id'] }
  end

  it 'returns 204 with a next token in the header and deletes the journal' do
    journal_id = register(credit: cash_payment)

    delete "/journals/#{journal_id}", headers: headers

    expect(response).to have_http_status(:no_content)
    expect(response.headers['X-Next-Token']).to be_present
    expect(Journal.exists?(journal_id)).to be(false)
  end

  it 'removes a card payment and its direct debit journal from the journal list' do
    journal_id = register(credit: card_payment)
    other_id = register(credit: cash_payment)
    expect(journal_ids.size).to eq(3)

    delete "/journals/#{journal_id}", headers: headers

    expect(journal_ids).to eq([ other_id ])
  end

  it "returns 404 for another user's journal and keeps it" do
    other = create(:user)
    other_cash = create(:asset_account, :cash, user: other)
    journal_id = register(credit: { element_type: 1, payment_method_type: 1, account_id: other_cash.id }, owner: other)

    delete "/journals/#{journal_id}", headers: headers

    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)['error']).to eq('journal_not_found')
    expect(response.headers['X-Next-Token']).to be_present
    expect(Journal.exists?(journal_id)).to be(true)
  end

  it 'returns 404 for a missing or out-of-range id' do
    delete '/journals/0', headers: headers
    expect(response).to have_http_status(:not_found)

    delete '/journals/99999999999', headers: headers
    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)['error']).to eq('journal_not_found')
  end

  it 'returns 422 for a direct debit journal and keeps both journals' do
    journal_id = register(credit: card_payment)
    direct_debit_id = DirectDebitJournal.find_by!(original_id: journal_id).direct_debit_id

    delete "/journals/#{direct_debit_id}", headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)['error']).to eq('direct_debit_journal_not_deletable')
    expect(Journal.where(id: [ journal_id, direct_debit_id ]).count).to eq(2)
  end

  it 'returns 401 without a token' do
    journal_id = register(credit: cash_payment)

    delete "/journals/#{journal_id}"

    expect(response).to have_http_status(:unauthorized)
    expect(Journal.exists?(journal_id)).to be(true)
  end
end
