# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /journals', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) { { 'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}" } }
  let(:repository) { Journals::InsertJournalEntry.new }

  let!(:food) { create(:expense_account, :food, :common) }
  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:tcard) { create(:liability_account, :tcard, user: user) }

  before { create(:credit_card, :tcard, user: user, liability_account: tcard, bank_account: bank) }

  def register(date:, amount: 1_000, store_name: 'まいばすけっと', owner: user, credit: nil)
    repository.insert_journal_entry!(
      journal_data: {
        date: date,
        user_id: owner.id,
        store_name: store_name,
        debits: [ { element_type: 5, account_id: food.id, amount: amount, item_name: 'パン' } ],
        credits: [ credit || { element_type: 1, payment_method_type: 1, account_id: cash.id, amount: amount } ]
      }
    )
  end

  def get_journals(params = {})
    get '/journals', params: params, headers: headers
    JSON.parse(response.body)
  end

  it 'returns journals with debits, credits and account names' do
    id = register(date: '2026-10-09', amount: 108)

    body = get_journals

    expect(response).to have_http_status(:ok)
    expect(body).to include('page' => 1, 'per_page' => 50, 'total_count' => 1)
    expect(body['journals'].sole).to include(
      'id' => id,
      'journal_date' => '2026-10-09',
      'store_name' => 'まいばすけっと',
      'debits' => [ { 'element_type' => 5, 'account_id' => food.id, 'account_name' => '食費', 'item_name' => 'パン', 'amount' => 108 } ],
      'credits' => [ { 'element_type' => 1, 'payment_method_type' => 1, 'account_id' => cash.id, 'account_name' => '現金', 'amount' => 108 } ],
      'original_journal_id' => nil,
      'direct_debit_journal_id' => nil
    )
  end

  it 'orders journals by date descending, then id descending' do
    older = register(date: '2026-10-01')
    newer = register(date: '2026-10-20')
    same_day_later = register(date: '2026-10-20')

    ids = get_journals['journals'].map { |j| j['id'] }

    expect(ids).to eq([ same_day_later, newer, older ])
  end

  it 'filters by the period, including both ends' do
    register(date: '2026-09-30')
    inside_start = register(date: '2026-10-01')
    inside_end = register(date: '2026-10-31')
    register(date: '2026-11-01')

    body = get_journals(from: '2026-10-01', to: '2026-10-31')

    expect(body['journals'].map { |j| j['id'] }).to contain_exactly(inside_start, inside_end)
    expect(body['total_count']).to eq(2)
  end

  it 'returns only the journals of the authenticated user' do
    mine = register(date: '2026-10-01')
    other = create(:user)
    other_cash = create(:asset_account, :cash, user: other)
    repository.insert_journal_entry!(
      journal_data: {
        date: '2026-10-01', user_id: other.id, store_name: 'other',
        debits: [ { element_type: 5, account_id: food.id, amount: 500, item_name: 'x' } ],
        credits: [ { element_type: 1, payment_method_type: 1, account_id: other_cash.id, amount: 500 } ]
      }
    )

    expect(get_journals['journals'].map { |j| j['id'] }).to eq([ mine ])
  end

  it 'paginates with 50 journals per page' do
    51.times { |i| register(date: Date.new(2026, 1, 1).next_day(i).to_s) }

    first = get_journals(page: 1)
    second = get_journals(page: 2)

    expect(first['journals'].size).to eq(50)
    expect(second['journals'].size).to eq(1)
    expect(first['total_count']).to eq(51)
    expect(second['page']).to eq(2)
    expect(second['journals'].sole['journal_date']).to eq('2026-01-01')
  end

  it 'returns an empty page beyond the last page' do
    register(date: '2026-10-01')

    body = get_journals(page: 5)

    expect(body['journals']).to eq([])
    expect(body['total_count']).to eq(1)
  end

  it 'links a credit card journal and its direct debit journal' do
    card_journal = register(
      date: '2026-10-09',
      credit: { element_type: 2, payment_method_type: 3, account_id: tcard.id, amount: 1_000 }
    )

    journals = get_journals['journals'].index_by { |j| j['id'] }
    debit_journal_id = (journals.keys - [ card_journal ]).sole

    expect(journals[card_journal]['direct_debit_journal_id']).to eq(debit_journal_id)
    expect(journals[card_journal]['original_journal_id']).to be_nil
    expect(journals[debit_journal_id]['original_journal_id']).to eq(card_journal)
    expect(journals[debit_journal_id]['journal_date']).to eq('2026-10-27')
    expect(journals[debit_journal_id]['credits'].sole['account_name']).to eq('三菱UFJ銀行 用賀出張所')
    expect(journals[debit_journal_id]['debits'].sole['account_name']).to eq('tcard')
  end

  it 'does not put next_token in the body' do
    register(date: '2026-10-01')

    expect(get_journals).not_to have_key('next_token')
  end

  it 'returns 422 for an invalid period or page' do
    body = get_journals(from: '2026-10-31', to: '2026-10-01', page: 0)

    expect(response).to have_http_status(:unprocessable_content)
    expect(body['errors']).to be_present
  end

  it 'returns 401 without a token' do
    get '/journals'

    expect(response).to have_http_status(:unauthorized)
  end
end
