# frozen_string_literal: true

require 'rails_helper'

# クレジットカードの一覧・追加・変更・削除（/credit-cards）
RSpec.describe 'Managing credit cards', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) do
    {
      'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}",
      'Content-Type' => 'application/json'
    }
  end

  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:mizuho) { create(:asset_account, :mizuho_tamagawa, user: user) }
  let!(:expense) { create(:expense_account, :eating_out, :common) }
  let!(:tcard) { create(:liability_account, :tcard, user: user) }

  before { create(:credit_card, :tcard, user: user, liability_account: tcard, bank_account: bank) }

  def body
    JSON.parse(response.body)
  end

  def cards
    get '/credit-cards', headers: headers
    body.to_h { |card| [ card['id'], card ] }
  end

  def pay_with(card)
    Journals::InsertJournalEntry.new.insert_journal_entry!(
      journal_data: {
        date: '2026-10-09', user_id: user.id, store_name: 'Aquavit 001',
        debits: [ { element_type: 5, account_id: expense.id, item_name: 'バー', amount: 1_000 } ],
        credits: [ { element_type: 2, payment_method_type: 3, account_id: card.id, amount: 1_000 } ]
      }
    )
  end

  let(:params) { { name: 'JAL', cutoff_day: 15, payment_day: 10, bank_account_id: mizuho.id } }

  describe 'GET /credit-cards' do
    it 'returns cards with their settings and whether they are in use' do
      pay_with(tcard)
      no_setting = create(:liability_account, :paypay, user: user)
      create(:liability_account, user: user, liability_type: :loan, name: '住宅ローン')
      create(:liability_account, :jal, user: create(:user))

      expect(cards).to eq(
        tcard.id => {
          'id' => tcard.id, 'name' => 'tcard', 'cutoff_day' => 10, 'payment_day' => 27,
          'bank_account_id' => bank.id, 'bank_account_name' => '三菱UFJ銀行 用賀出張所', 'in_use' => true
        },
        no_setting.id => {
          'id' => no_setting.id, 'name' => 'PayPay', 'cutoff_day' => nil, 'payment_day' => nil,
          'bank_account_id' => nil, 'bank_account_name' => nil, 'in_use' => false
        }
      )
    end
  end

  describe 'POST /credit-cards' do
    it 'returns 201 and creates the card with its setting, which can be used to pay' do
      post '/credit-cards', params: params.to_json, headers: headers

      expect(response).to have_http_status(:created)
      expect(body['next_token']).to be_present

      card = LiabilityAccount.find(body['id'])
      expect([ card.user_id, card.name, card.liability_type ]).to eq([ user.id, 'JAL', 'credit_card' ])
      expect(cards[card.id]).to include('cutoff_day' => 15, 'payment_day' => 10, 'bank_account_id' => mizuho.id)

      # 締め日 15 日・支払日 10 日なので、10 月 9 日の買い物は 11 月 10 日に引き落とされる
      journal_id = pay_with(card)
      direct_debit = Journal.find(DirectDebitJournal.find_by!(original_id: journal_id).direct_debit_id)
      expect(direct_debit.journal_dt).to eq(Date.new(2026, 11, 10))
      expect(direct_debit.credits.sole.account_id).to eq(mizuho.id)
    end

    it 'returns 422 for a duplicate name' do
      post '/credit-cards', params: params.merge(name: 'tcard').to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(body).to include('error' => 'duplicate_account_name')
      expect(body['next_token']).to be_present
    end

    it 'returns 404 for a bank account that is not a deposit account of the user' do
      other_bank = create(:asset_account, :mufg_yoga, user: create(:user))

      [ cash.id, other_bank.id, 0 ].each do |bank_account_id|
        expect do
          post '/credit-cards', params: params.merge(bank_account_id: bank_account_id).to_json, headers: headers
        end.not_to change(LiabilityAccount, :count)

        expect(response).to have_http_status(:not_found)
        expect(body['error']).to eq('bank_account_not_found')
      end
    end

    it 'returns 422 with errors for an invalid request' do
      post '/credit-cards', params: params.merge(name: '', cutoff_day: 0, payment_day: 32, bank_account_id: nil).to_json,
                            headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['errors']).to contain_exactly(
        "Name can't be blank",
        'Cutoff day must be an integer between 1 and 31',
        'Payment day must be an integer between 1 and 31',
        'Bank account must be a positive integer'
      )
    end
  end

  describe 'PUT /credit-cards/:id' do
    it 'changes the name and the setting of a card in use, keeping existing direct debits' do
      journal_id = pay_with(tcard)
      direct_debit_id = DirectDebitJournal.find_by!(original_id: journal_id).direct_debit_id

      put "/credit-cards/#{tcard.id}", params: params.merge(name: 'T カード').to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(body).to include('id' => tcard.id)
      expect(cards[tcard.id]).to include('name' => 'T カード', 'cutoff_day' => 15, 'payment_day' => 10,
                                         'bank_account_id' => mizuho.id)
      expect(Journal.find(direct_debit_id).journal_dt).to eq(Date.new(2026, 10, 27))
    end

    it 'creates the missing setting of a card' do
      paypay = create(:liability_account, :paypay, user: user)

      put "/credit-cards/#{paypay.id}", params: params.merge(name: 'PayPay').to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(cards[paypay.id]).to include('cutoff_day' => 15, 'bank_account_id' => mizuho.id)
    end

    it "returns 404 for another user's card or a liability that is not a card" do
      other_card = create(:liability_account, :jal, user: create(:user))
      loan = create(:liability_account, user: user, liability_type: :loan, name: '住宅ローン')

      [ other_card, loan ].each do |account|
        put "/credit-cards/#{account.id}", params: params.to_json, headers: headers

        expect(response).to have_http_status(:not_found)
        expect(body['error']).to eq('credit_card_not_found')
      end
    end
  end

  describe 'DELETE /credit-cards/:id' do
    it 'returns 204 and deletes an unused card with its setting' do
      delete "/credit-cards/#{tcard.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(response.headers['X-Next-Token']).to be_present
      expect(LiabilityAccount.exists?(tcard.id)).to be(false)
      expect(CreditCard.where(liability_account_id: tcard.id)).to be_empty
    end

    it 'returns 422 for a card used by a journal' do
      pay_with(tcard)

      delete "/credit-cards/#{tcard.id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('credit_card_in_use')
      expect(LiabilityAccount.exists?(tcard.id)).to be(true)
    end
  end

  it 'returns 401 without a token' do
    get '/credit-cards'

    expect(response).to have_http_status(:unauthorized)
  end
end
