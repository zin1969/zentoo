# frozen_string_literal: true
#
# spec/requests/accounts/expense_accounts_spec.rb

require 'rails_helper'

RSpec.describe 'GET /expense-accounts', type: :request do
  let(:user) { create(:user, :masa) }

  before do
    create(:expense_account, :food, user: user)
  end

  it 'returns 200 with id and name' do
    get '/expense-accounts'

    expect(response).to have_http_status(:ok)

    body = JSON.parse(response.body)

    expect(body.map { |a| a['name'] }).to include('食費')
  end
end
