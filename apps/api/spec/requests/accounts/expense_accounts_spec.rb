# frozen_string_literal: true

#
# spec/requests/accounts/expense_accounts_spec.rb

require 'rails_helper'

RSpec.describe 'GET /expense-accounts', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) { { 'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}" } }

  before do
    create(:expense_account, :food, user: user)
  end

  it 'returns 200 with id and name' do
    get '/expense-accounts', headers: headers

    expect(response).to have_http_status(:ok)

    body = JSON.parse(response.body)

    expect(body.map { |a| a['name'] }).to include('食費')
  end

  it 'returns only the accounts of the authenticated user' do
    create(:expense_account, name: 'other-user-expense', user: create(:user))

    get '/expense-accounts', headers: headers

    names = JSON.parse(response.body).map { |a| a['name'] }
    expect(names).to eq([ '食費' ])
  end

  it 'returns 401 without a token' do
    get '/expense-accounts'

    expect(response).to have_http_status(:unauthorized)
  end
end
