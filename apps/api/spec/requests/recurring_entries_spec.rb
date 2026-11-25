# frozen_string_literal: true

require 'rails_helper'

# 決まった支払いの一覧・追加・変更・削除（/recurring-entries）
RSpec.describe 'Recurring entries', type: :request do
  let(:user) { create(:user, :masa) }
  let(:other_user) { create(:user) }
  let(:headers) do
    {
      'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}",
      'Content-Type' => 'application/json'
    }
  end

  let!(:rent) { create(:expense_account, :common, name: '家賃') }
  let!(:salary) { create(:revenue_account, :salary, :common) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:tcard) { create(:liability_account, :tcard, user: user) }

  let(:rent_params) do
    {
      name: '家賃', kind: 1, store_name: '大家', item_name: '12 月分', amount: 85_000,
      debit_account_id: rent.id, credit_element_type: 1, credit_account_id: bank.id,
      interval_unit: 1, interval_count: 1, day_of_month: 27, start_date: '2026-11-01'
    }
  end

  let(:salary_params) do
    {
      name: '給料', kind: 2, amount: 250_000,
      debit_account_id: bank.id, credit_element_type: 4, credit_account_id: salary.id,
      interval_unit: 1, interval_count: 1, day_of_month: 25, start_date: '2026-11-01'
    }
  end

  def body
    JSON.parse(response.body)
  end

  def create_entry(params)
    post '/recurring-entries', headers: headers, params: params.to_json
    body['id']
  end

  describe 'POST /recurring-entries and GET /recurring-entries' do
    it 'adds an expense and an income, and lists them with the account names and the next date' do
      travel_to(Time.zone.local(2026, 11, 26, 9, 0)) do
        create_entry(rent_params)
        expect(response).to have_http_status(:created)
        expect(body['next_token']).to be_present
        create_entry(salary_params.merge(interval_count: 12, day_of_month: 31, start_date: '2026-12-01'))
        create(:recurring_entry, user: other_user, debit_account_id: rent.id, credit_account_id: bank.id)

        get '/recurring-entries', headers: headers
      end

      expect(response).to have_http_status(:ok)
      expect(body.size).to eq(2)
      expect(body.first).to include(
        'name' => '家賃', 'kind' => 1, 'store_name' => '大家', 'item_name' => '12 月分', 'amount' => 85_000,
        'debit_account_id' => rent.id, 'debit_account_name' => '家賃',
        'credit_element_type' => 1, 'credit_account_id' => bank.id, 'credit_account_name' => bank.name,
        'interval_unit' => 1, 'interval_count' => 1, 'day_of_month' => 27, 'weekday' => nil,
        'start_date' => '2026-11-01', 'end_date' => nil, 'next_date' => '2026-11-27'
      )
      expect(body.second).to include('credit_account_name' => salary.name, 'next_date' => '2026-12-31')
    end

    it 'returns no next date once the entry has ended' do
      # トークンは 15 分で切れるので、作るところから日付を進めておく
      travel_to(Time.zone.local(2026, 12, 1, 9, 0)) do
        create_entry(rent_params.merge(end_date: '2026-11-30'))
        get '/recurring-entries', headers: headers
      end

      expect(body.sole['next_date']).to be_nil
    end

    it 'accepts a credit card as the payment method' do
      create_entry(rent_params.merge(credit_element_type: 2, credit_account_id: tcard.id))

      expect(response).to have_http_status(:created)
    end

    it 'returns 422 for values that do not fit' do
      create_entry(rent_params.merge(name: ' ', amount: 0, credit_element_type: 4, day_of_month: 32, interval_count: 13))

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['errors']).to include(
        "Name can't be blank",
        'Amount must be an integer between 1 and 2147483647',
        'Credit element type must be one of 1, 2 for this kind',
        'Day of month must be an integer between 1 and 31',
        'Interval count must be an integer between 1 and 12'
      )
      expect(body['next_token']).to be_present
    end

    it 'accepts a weekly entry with a weekday, and ignores the day of the month' do
      travel_to(Time.zone.local(2026, 11, 26, 9, 0)) do
        create_entry(rent_params.merge(interval_unit: 2, interval_count: 2, weekday: 5))
        expect(response).to have_http_status(:created)

        get '/recurring-entries', headers: headers
      end

      expect(body.sole).to include('interval_unit' => 2, 'interval_count' => 2, 'weekday' => 5, 'day_of_month' => nil,
                                   'next_date' => '2026-12-04')
    end

    it 'returns 422 for a weekly entry without a weekday, an unknown unit, or an end before the start' do
      create_entry(rent_params.merge(interval_unit: 2, weekday: 7))
      expect(body['errors']).to include('Weekday must be an integer between 0 (Sunday) and 6 (Saturday)')

      create_entry(rent_params.merge(interval_unit: 3, end_date: '2026-10-31'))
      expect(body['errors']).to include('Interval unit must be 1 (month) or 2 (week)',
                                        'End date must be on or after the start date')
    end

    it "returns 404 for an account that is not the user's or does not match the kind" do
      others_bank = create(:asset_account, :mufg_yoga, user: other_user)

      create_entry(rent_params.merge(credit_account_id: others_bank.id))
      expect(response).to have_http_status(:not_found)
      expect(body['error']).to eq('account_not_found')

      create_entry(salary_params.merge(debit_account_id: rent.id))
      expect(body['error']).to eq('account_not_found')
      expect(RecurringEntry.count).to eq(0)
    end
  end

  describe 'PUT /recurring-entries/:id' do
    it 'changes the entry' do
      id = create_entry(rent_params)

      put "/recurring-entries/#{id}", headers: headers, params: rent_params.merge(amount: 86_000, interval_count: 3).to_json

      expect(response).to have_http_status(:ok)
      expect(RecurringEntry.find(id)).to have_attributes(amount: 86_000, interval_count: 3)
    end

    it "returns 404 for another user's entry" do
      others = create(:recurring_entry, user: other_user, debit_account_id: rent.id, credit_account_id: bank.id)

      put "/recurring-entries/#{others.id}", headers: headers, params: rent_params.to_json

      expect(response).to have_http_status(:not_found)
      expect(body['error']).to eq('recurring_entry_not_found')
    end
  end

  describe 'DELETE /recurring-entries/:id' do
    it 'deletes the entry and its occurrences' do
      id = create_entry(rent_params)
      RecurringEntryOccurrence.create!(recurring_entry_id: id, scheduled_date: Date.new(2026, 11, 27), skipped: true)

      delete "/recurring-entries/#{id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(RecurringEntry.count).to eq(0)
      expect(RecurringEntryOccurrence.count).to eq(0)
    end

    it "returns 404 for another user's entry" do
      others = create(:recurring_entry, user: other_user, debit_account_id: rent.id, credit_account_id: bank.id)

      delete "/recurring-entries/#{others.id}", headers: headers

      expect(response).to have_http_status(:not_found)
      expect(RecurringEntry.count).to eq(1)
    end
  end

  describe 'accounts used by an entry' do
    it 'cannot be deleted' do
      create_entry(rent_params)

      delete "/asset-accounts/#{bank.id}", headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('asset_account_in_use')

      delete "/expense-accounts/#{rent.id}", headers: headers
      expect(body['error']).to eq('expense_account_in_use')
    end
  end
end
