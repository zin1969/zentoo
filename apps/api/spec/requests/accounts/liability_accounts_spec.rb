# frozen_string_literal: true

#
# spec/requests/accounts/liability_accounts_spec.rb

require 'rails_helper'

RSpec.describe 'GET /liability-accounts', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) { { 'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}" } }

  before do
    create(:liability_account, :jal, user: user)
  end

  it 'returns 200 with id, name, element_type and payment_method_type' do
    get '/liability-accounts', headers: headers

    expect(response).to have_http_status(:ok)

    body = JSON.parse(response.body)

    jal = body.find { |a| a['name'] == 'JAL' }
    expect(jal['element_type']).to eq(2)
    expect(jal['payment_method_type']).to eq(3)
  end

  it 'returns only the accounts of the authenticated user' do
    create(:liability_account, name: 'other-user-liability', user: create(:user))

    get '/liability-accounts', headers: headers

    names = JSON.parse(response.body).map { |a| a['name'] }
    expect(names).to eq([ 'JAL' ])
  end

  it 'returns 401 without a token' do
    get '/liability-accounts'

    expect(response).to have_http_status(:unauthorized)
  end
end
