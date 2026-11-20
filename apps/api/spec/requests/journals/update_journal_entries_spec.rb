# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PUT /journal-entries/:id', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) do
    {
      'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}",
      'Content-Type' => 'application/json'
    }
  end

  let!(:eating_out) { create(:expense_account, :eating_out, :common) }
  let!(:movie) { create(:expense_account, :movie, :common) }
  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:tcard) { create(:liability_account, :tcard, user: user) }

  before { create(:credit_card, :tcard, user: user, liability_account: tcard, bank_account: bank) }

  let(:cash_payment) { { element_type: 1, payment_method_type: 1, account_id: cash.id } }
  let(:card_payment) { { element_type: 2, payment_method_type: 3, account_id: tcard.id } }

  def entry(credit:, expense: eating_out, item_name: 'バー', amount: 3_300)
    {
      date: '2026-10-20',
      store_name: 'Aquavit 001',
      debits: [ { element_type: 5, account_id: expense.id, item_name: item_name, amount: amount } ],
      credits: [ credit.merge(amount: amount) ]
    }
  end

  def register(credit:, owner: user)
    Journals::InsertJournalEntry.new.insert_journal_entry!(journal_data: entry(credit: credit).merge(user_id: owner.id))
  end

  def put_entry(journal_id, body)
    put "/journal-entries/#{journal_id}", params: body.to_json, headers: headers
  end

  it 'returns 200 with the new journal id and a next token, and replaces the journal' do
    journal_id = register(credit: card_payment)

    put_entry(journal_id, entry(credit: cash_payment, expense: movie, item_name: '映画', amount: 2_000))

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['next_token']).to be_present
    expect(Journal.exists?(journal_id)).to be(false)

    journal = Journal.find(body['journal_id'])
    expect(journal.user_id).to eq(user.id)
    expect(journal.debits.sole.attributes.values_at('account_id', 'item_name')).to eq([ movie.id, '映画' ])
    expect(journal.credits.sole.account_id).to eq(cash.id)
    expect(DirectDebitJournal.count).to eq(0)
  end

  it 'ignores a user_id in the request' do
    journal_id = register(credit: cash_payment)

    put_entry(journal_id, entry(credit: cash_payment).merge(user_id: create(:user).id))

    expect(Journal.find(JSON.parse(response.body)['journal_id']).user_id).to eq(user.id)
  end

  it "returns 404 for another user's journal" do
    other = create(:user)
    other_cash = create(:asset_account, :cash, user: other)
    journal_id = register(credit: { element_type: 1, payment_method_type: 1, account_id: other_cash.id }, owner: other)

    put_entry(journal_id, entry(credit: cash_payment))

    expect(response).to have_http_status(:not_found)
    body = JSON.parse(response.body)
    expect(body['error']).to eq('journal_not_found')
    expect(body['next_token']).to be_present
  end

  it 'returns 422 for a direct debit journal' do
    journal_id = register(credit: card_payment)
    direct_debit_id = DirectDebitJournal.find_by!(original_id: journal_id).direct_debit_id

    put_entry(direct_debit_id, entry(credit: cash_payment))

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)['error']).to eq('direct_debit_journal_not_editable')
  end

  it 'returns 422 for a journal that is not a shopping journal' do
    deposit_id = Journals::CreateCashDeposit.new.create_cash_deposit!(
      journal_date: Date.new(2026, 10, 20), bank_account_id: bank.id, amount: 45_000, user_id: user.id
    )

    put_entry(deposit_id, entry(credit: cash_payment))

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)['error']).to eq('journal_not_editable')
  end

  it 'returns 422 and keeps the journal when the new content debits something other than expenses' do
    journal_id = register(credit: cash_payment)
    body = entry(credit: cash_payment)
    body[:debits] = [ { element_type: 1, account_id: bank.id, item_name: '預入', amount: 3_300 } ]

    put_entry(journal_id, body)

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)['error']).to eq('expense_debits_required')
    expect(Journal.exists?(journal_id)).to be(true)
  end

  it 'returns 422 and keeps the journal when the new content is unbalanced' do
    journal_id = register(credit: cash_payment)
    body = entry(credit: cash_payment)
    body[:credits].first[:amount] = 1

    put_entry(journal_id, body)

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)['error']).to eq('unbalanced_journal')
    expect(Journal.exists?(journal_id)).to be(true)
  end

  it 'returns 422 with errors for an invalid request' do
    journal_id = register(credit: cash_payment)

    put_entry(journal_id, entry(credit: cash_payment).merge(date: nil))

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)['errors']).to be_present
    expect(Journal.exists?(journal_id)).to be(true)
  end

  it 'returns 401 without a token' do
    journal_id = register(credit: cash_payment)

    put "/journal-entries/#{journal_id}", params: entry(credit: cash_payment).to_json,
                                          headers: { 'Content-Type' => 'application/json' }

    expect(response).to have_http_status(:unauthorized)
    expect(Journal.exists?(journal_id)).to be(true)
  end
end
