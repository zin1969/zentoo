# frozen_string_literal: true

#
# spec/requests/sessions_spec.rb

require 'rails_helper'

RSpec.describe 'POST /login', type: :request do
  let!(:user) { create(:user, :masa, password: 'secret-pass') }
  let(:headers) { { 'Content-Type' => 'application/json' } }

  it 'returns 201 with a token that authenticates the user' do
    post '/login', params: { name: 'masa', password: 'secret-pass' }.to_json, headers: headers

    expect(response).to have_http_status(:created)

    token = JSON.parse(response.body)['token']
    expect(TokenAuthenticator.new.authenticate!(token)).to eq(user)
  end

  it 'returns 401 when the password is wrong' do
    post '/login', params: { name: 'masa', password: 'wrong' }.to_json, headers: headers

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)).to eq('error' => 'unauthorized')
  end

  it 'returns 401 when the user does not exist' do
    post '/login', params: { name: 'nobody', password: 'secret-pass' }.to_json, headers: headers

    expect(response).to have_http_status(:unauthorized)
  end

  it 'returns 401 when the user has no password set' do
    create(:user, :system)

    post '/login', params: { name: 'system', password: '' }.to_json, headers: headers

    expect(response).to have_http_status(:unauthorized)
  end

  it 'returns 401 when the parameters are missing' do
    post '/login', params: {}.to_json, headers: headers

    expect(response).to have_http_status(:unauthorized)
  end
end
