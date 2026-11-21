# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /bank-account-ledgers/:id', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) { { 'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}" } }

  let!(:food) { create(:expense_account, :food, :common) }
  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:tcard) { create(:liability_account, :tcard, user: user) }

  before do
    create(:equity_account, :original_deposit, :common)
    # 10 日締め・27 日払い
    create(:credit_card, :tcard, user: user, liability_account: tcard, bank_account: bank)

    Journals::CreateOpeningAsset.new.create_opening_asset_balance!(
      journal_date: Date.new(2026, 10, 1), asset_type: ElementType.new(ElementType::ASSETS),
      asset_account_id: bank.id, amount: Amount.new(10_000), user_id: user.id
    )
  end

  def buy(date:, amount:, store:, credits: nil)
    Journals::InsertJournalEntry.new.insert_journal_entry!(
      journal_data: {
        date: date, user_id: user.id, store_name: store,
        debits: [ { element_type: 5, account_id: food.id, item_name: '食材', amount: amount } ],
        credits: credits || [ { element_type: 2, payment_method_type: 3, account_id: tcard.id, amount: amount } ]
      }
    )
  end

  def body
    JSON.parse(response.body)
  end

  it 'returns the account, the period and the entries with a next token header' do
    first = buy(date: '2026-10-05', amount: 3_000, store: 'スーパー')
    # 現金とカードで分けて払った買い物は、カードで払った額だけが内訳に出る
    second = buy(date: '2026-10-08', amount: 2_500, store: '八百屋', credits: [
      { element_type: 1, payment_method_type: 1, account_id: cash.id, amount: 500 },
      { element_type: 2, payment_method_type: 3, account_id: tcard.id, amount: 2_000 }
    ])

    travel_to Time.zone.local(2026, 10, 20, 12) do
      get "/bank-account-ledgers/#{bank.id}", params: { from: '2026-10-01', to: '2026-10-31' }, headers: headers
    end

    expect(response).to have_http_status(:ok)
    expect(response.headers['X-Next-Token']).to be_present
    expect(body).to include(
      'account' => { 'id' => bank.id, 'name' => '三菱UFJ銀行 用賀出張所' },
      'from' => '2026-10-01', 'to' => '2026-10-31', 'today' => '2026-10-20'
    )

    carried, opening, card = body['entries']
    expect(carried).to include('row_type' => 'carried_over', 'date' => '2026-09-30', 'balance' => 0, 'scheduled' => false)
    expect(opening).to include('row_type' => 'journal', 'description' => '開始残高', 'deposit' => 10_000,
                               'balance' => 10_000, 'scheduled' => false, 'items' => [])
    expect(card).to include(
      'row_type' => 'card_payment', 'date' => '2026-10-27', 'description' => 'tcard', 'withdrawal' => 5_000,
      'balance' => 5_000, 'scheduled' => true, 'card_account_id' => tcard.id, 'journal_ids' => [ first, second ]
    )
    expect(card['items']).to eq([
      { 'journal_id' => first, 'journal_date' => '2026-10-05', 'store_name' => 'スーパー', 'amount' => 3_000 },
      { 'journal_id' => second, 'journal_date' => '2026-10-08', 'store_name' => '八百屋', 'amount' => 2_000 }
    ])
  end

  it 'defaults to the start of last month until the last scheduled date' do
    buy(date: '2026-11-15', amount: 1_000, store: 'スーパー')

    travel_to Time.zone.local(2026, 10, 20, 12) do
      get "/bank-account-ledgers/#{bank.id}", headers: headers
    end

    # 11 月 15 日の買い物は、12 月 27 日（日曜）の翌営業日 28 日に引き落とされる
    expect(body).to include('from' => '2026-09-01', 'to' => '2026-12-28')
    expect(body['entries'].last).to include('date' => '2026-12-28', 'scheduled' => true)
  end

  it 'defaults to the end of this month when there is nothing scheduled after it' do
    travel_to Time.zone.local(2026, 10, 20, 12) do
      get "/bank-account-ledgers/#{bank.id}", headers: headers
    end

    expect(body).to include('from' => '2026-09-01', 'to' => '2026-10-31')
  end

  it "returns 404 for a cash account or another user's account" do
    other_bank = create(:asset_account, :mufg_yoga, user: create(:user))

    [ cash, other_bank ].each do |account|
      get "/bank-account-ledgers/#{account.id}", headers: headers

      expect(response).to have_http_status(:not_found)
      expect(body['error']).to eq('asset_account_not_found')
    end
  end

  it 'returns 422 for an invalid period' do
    get "/bank-account-ledgers/#{bank.id}", params: { from: '2026-10-31', to: '2026-10-01' }, headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(body['errors']).to eq([ 'To must not be earlier than from' ])
  end

  it 'returns 401 without a token' do
    get "/bank-account-ledgers/#{bank.id}"

    expect(response).to have_http_status(:unauthorized)
  end
end
