# frozen_string_literal: true

require 'rails_helper'

# 決まった支払いの回: 未登録の回の一覧（GET /recurring-entries/pending）と、
# 確かめてからの登録（POST /recurring-entries/:id/occurrences）・飛ばす（POST /recurring-entries/:id/skips）
RSpec.describe 'Recurring occurrences', type: :request do
  let(:user) { create(:user, :masa) }
  let(:other_user) { create(:user) }
  let(:headers) do
    {
      'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}",
      'Content-Type' => 'application/json'
    }
  end

  let!(:rent_account) { create(:expense_account, :common, name: '家賃') }
  let!(:salary_account) { create(:revenue_account, :salary, :common) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:tcard) { create(:liability_account, :tcard, user: user) }

  # 10 月から毎月 27 日の家賃（銀行振込）と、11 月から毎月 25 日の給料
  let!(:rent) do
    create(:recurring_entry, user: user, name: '家賃', store_name: '大家', amount: 85_000, day_of_month: 27,
                             debit_account_id: rent_account.id, credit_account_id: bank.id, start_date: Date.new(2026, 10, 1))
  end
  let!(:salary) do
    create(:recurring_entry, user: user, name: '給料', kind: 2, amount: 250_000, day_of_month: 25,
                             debit_account_id: bank.id, credit_element_type: 4, credit_account_id: salary_account.id,
                             start_date: Date.new(2026, 11, 1))
  end

  def body
    JSON.parse(response.body)
  end

  # 「今日」は 2026-11-26。トークンは 15 分で切れるので、リクエストもこの中で送る
  def on_today(&block)
    travel_to(Time.zone.local(2026, 11, 26, 9, 0), &block)
  end

  def register(entry, params)
    post "/recurring-entries/#{entry.id}/occurrences", headers: headers, params: params.to_json
  end

  def skip(entry, scheduled_date)
    post "/recurring-entries/#{entry.id}/skips", headers: headers, params: { scheduled_date: scheduled_date }.to_json
  end

  # 金額は値オブジェクト（Amount）なので、整数にして比べる
  def line(row)
    [ row.account_id, row.amount.to_i ]
  end

  def pending
    get '/recurring-entries/pending', headers: headers
    body.map { |row| [ row['name'], row['scheduled_date'] ] }
  end

  describe 'GET /recurring-entries/pending' do
    it 'lists the dates up to the end of this month that are not registered or skipped, including left-over ones' do
      on_today do
        create(:recurring_entry, user: other_user, debit_account_id: rent_account.id, credit_account_id: bank.id)

        expect(pending).to eq([ [ '家賃', '2026-10-27' ], [ '給料', '2026-11-25' ], [ '家賃', '2026-11-27' ] ])
        expect(body.first).to include(
          'recurring_entry_id' => rent.id, 'kind' => 1, 'amount' => 85_000, 'store_name' => '大家',
          'debit_account_name' => '家賃', 'credit_account_name' => bank.name
        )
      end
    end
  end

  describe 'POST /recurring-entries/:id/occurrences' do
    it 'registers an expense with the checked amount and takes it off the pending list' do
      on_today do
        register(rent, scheduled_date: '2026-10-27', amount: 86_000)

        expect(response).to have_http_status(:created)
        expect(body['next_token']).to be_present
        journal = Journal.find(body['journal_id'])
        expect(journal.journal_dt).to eq(Date.new(2026, 10, 27))
        expect(line(journal.debits.sole)).to eq([ rent_account.id, 86_000 ])
        expect(journal.debits.sole.item_name).to eq('家賃')
        expect(line(journal.credits.sole)).to eq([ bank.id, 86_000 ])
        expect(pending).to eq([ [ '給料', '2026-11-25' ], [ '家賃', '2026-11-27' ] ])
      end
    end

    it 'registers an income on the date it was actually paid' do
      on_today do
        register(salary, scheduled_date: '2026-11-25', date: '2026-11-26', amount: 250_000)

        expect(response).to have_http_status(:created)
        journal = Journal.find(body['journal_id'])
        expect(journal.journal_dt).to eq(Date.new(2026, 11, 26))
        expect(line(journal.debits.sole)).to eq([ bank.id, 250_000 ])
        expect(line(journal.credits.sole)).to eq([ salary_account.id, 250_000 ])
        expect(RecurringEntryOccurrence.sole).to have_attributes(scheduled_date: Date.new(2026, 11, 25), journal_id: journal.id)
      end
    end

    it 'makes the direct debit journal for a card payment' do
      rent.update!(credit_element_type: 2, credit_account_id: tcard.id)
      create(:credit_card, :tcard, user: user, liability_account: tcard, bank_account: bank)

      on_today { register(rent, scheduled_date: '2026-11-27', amount: 85_000) }

      expect(response).to have_http_status(:created)
      expect(DirectDebitJournal.where(original_id: body['journal_id'])).to exist
    end

    it 'returns 422 for a date that is not scheduled or already recorded, and for a bad amount' do
      on_today do
        register(rent, scheduled_date: '2026-11-26', amount: 85_000)
        expect(response).to have_http_status(:unprocessable_content)
        expect(body['error']).to eq('not_scheduled_date')

        register(rent, scheduled_date: '2026-11-27', amount: 0)
        expect(body['errors']).to include('Amount must be an integer between 1 and 2147483647')

        register(rent, scheduled_date: '2026-11-27', amount: 85_000)
        register(rent, scheduled_date: '2026-11-27', amount: 85_000)
        expect(body['error']).to eq('occurrence_already_recorded')
        expect(Journal.count).to eq(1)
      end
    end

    it "returns 404 for another user's entry" do
      others = create(:recurring_entry, user: other_user, debit_account_id: rent_account.id, credit_account_id: bank.id)

      on_today { register(others, scheduled_date: '2026-11-27', amount: 85_000) }

      expect(response).to have_http_status(:not_found)
      expect(body['error']).to eq('recurring_entry_not_found')
    end
  end

  describe 'POST /recurring-entries/:id/occurrences for a transfer' do
    let!(:securities) { create(:asset_account, :securities, user: user) }
    let!(:suica) { create(:asset_account, :suica, user: user) }

    # 11 月から毎月 27 日に、銀行から証券口座へ入金する
    def transfer_entry(**attributes)
      create(:recurring_entry, user: user, name: '証券口座へ入金', kind: 3, amount: 33_333, day_of_month: 27,
                               debit_account_id: securities.id, credit_element_type: 1, credit_account_id: bank.id,
                               start_date: Date.new(2026, 11, 1), **attributes)
    end

    it 'registers a transfer with the name as its description, and keeps the occurrence when the journal is replaced' do
      entry = transfer_entry

      on_today do
        register(entry, scheduled_date: '2026-11-27', amount: 30_000)

        expect(response).to have_http_status(:created)
        journal = Journal.find(body['journal_id'])
        expect(journal).to have_attributes(journal_dt: Date.new(2026, 11, 27), store_name: '証券口座へ入金')
        expect(line(journal.debits.sole)).to eq([ securities.id, 30_000 ])
        expect(journal.credits.sole.element_type).to eq(ElementType::ASSETS)
        expect(journal.credits.sole.payment_method_type).to eq(2)
        expect(line(journal.credits.sole)).to eq([ bank.id, 30_000 ])

        put "/transfer-journals/#{journal.id}", headers: headers, params: {
          journal_date: '2026-11-28', from_type: 'asset', from_account_id: bank.id, to_account_id: securities.id,
          amount: 33_333, description: '証券口座へ入金'
        }.to_json

        expect(response).to have_http_status(:ok)
        expect(RecurringEntryOccurrence.sole).to have_attributes(scheduled_date: Date.new(2026, 11, 27),
                                                                 journal_id: body['journal_id'])
        expect(pending).not_to include([ '証券口座へ入金', '2026-11-27' ])
      end
    end

    it 'makes the direct debit journal for a charge from a credit card' do
      create(:credit_card, :tcard, user: user, liability_account: tcard, bank_account: bank)
      entry = transfer_entry(name: 'オートチャージ', store_name: 'Suica チャージ', debit_account_id: suica.id,
                             credit_element_type: 2, credit_account_id: tcard.id)

      on_today { register(entry, scheduled_date: '2026-11-27', amount: 3_000) }

      expect(response).to have_http_status(:created)
      expect(Journal.find(body['journal_id']).store_name).to eq('Suica チャージ')
      expect(DirectDebitJournal.where(original_id: body['journal_id'])).to exist
    end

    it 'returns 422 for a charge from a card into an account that is not e-money' do
      create(:credit_card, :tcard, user: user, liability_account: tcard, bank_account: bank)
      entry = transfer_entry(credit_element_type: 2, credit_account_id: tcard.id)

      on_today { register(entry, scheduled_date: '2026-11-27', amount: 3_000) }

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('credit_card_charge_requires_e_money')
      expect(Journal.count).to eq(0)
      expect(RecurringEntryOccurrence.count).to eq(0)
    end
  end

  describe 'POST /recurring-entries/:id/skips' do
    it 'skips a date, brings back a date whose journal was deleted, and refuses to record a date twice' do
      on_today do
        skip(rent, '2026-10-27')
        expect(response).to have_http_status(:created)
        expect(pending).to eq([ [ '給料', '2026-11-25' ], [ '家賃', '2026-11-27' ] ])

        register(salary, scheduled_date: '2026-11-25', amount: 250_000)
        delete "/journals/#{body['journal_id']}", headers: headers
        expect(pending).to eq([ [ '給料', '2026-11-25' ], [ '家賃', '2026-11-27' ] ])

        skip(rent, '2026-10-27')
        expect(body['error']).to eq('occurrence_already_recorded')
      end
    end
  end
end
