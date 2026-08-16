# frozen_string_literal: true
#
# spec/requests/journals/journal_entries_spec.rb

require 'rails_helper'
require 'ostruct'

RSpec.describe 'POST /journal-entries', type: :request do
  let(:path) { '/journal-entries' }
  let(:headers) do
    {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
  end

  let(:token) { 'dummy-token' }

  let(:params) do
    {
      date: '2026-07-19',
      user_id: 999, # 認証済みユーザーIDで上書きされるはずの値
      store_name: 'ピザーラ',
      debits: [
        {
          element_type: 5,
          account_id: 10_051,
          amount: 1_000,
          item_name: 'ピザ'
        }
      ],
      credits: [
        {
          element_type: 1,
          payment_method_type: 1,
          account_id: 5,
          amount: 1_000
        }
      ]
    }
  end

  let(:validated_data) do
    {
      date: Date.new(2026, 7, 19),
      user_id: 999,
      store_name: 'ピザーラ',
      debits: [
        {
          element_type: ElementType.new(5),
          account_id: 10_051,
          amount: Amount.new(1_000),
          item_name: 'ピザ'
        }
      ],
      credits: [
        {
          element_type: ElementType.new(1),
          payment_method_type: 1,
          account_id: 5,
          amount: Amount.new(1_000)
        }
      ]
    }
  end

  let(:user) { OpenStruct.new(id: 1) }
  let(:authenticator) { instance_double(TokenAuthenticator) }
  let(:token_manager) { instance_double(TokenManager) }
  let(:form) { instance_double(InsertJournalEntryForm) }
  let(:service) { instance_double(Journals::InsertJournalEntryService) }

  describe 'success' do
    before do
      # Auth
      allow(TokenAuthenticator).to receive(:new).and_return(authenticator)
      allow(authenticator).to receive(:authenticate!).and_return(user)

      # Token
      allow(TokenManager).to receive(:new).and_return(token_manager)
      allow(token_manager)
        .to receive(:issue_next_token)
        .and_return('abc.def.ghi')

      # Form
      allow(InsertJournalEntryForm).to receive(:new).and_return(form)
      allow(form).to receive(:validated_data).and_return(validated_data)

      # Service
      allow(Journals::InsertJournalEntryService)
        .to receive(:new)
        .and_return(service)

      allow(service).to receive(:call).and_return(456)
    end

    it 'returns 201, journal_id and next_token, overriding user_id with the authenticated user' do
      post path, params: params.to_json, headers: headers

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)

      expect(body['journal_id']).to eq(456)
      expect(body['next_token']).to eq('abc.def.ghi')

      expect(service).to have_received(:call).with(
        journal_data: validated_data.merge(user_id: user.id)
      )
    end
  end

  describe 'validation error' do
    before do
      allow(TokenAuthenticator).to receive(:new).and_return(authenticator)
      allow(authenticator).to receive(:authenticate!).and_return(user)

      allow(TokenManager).to receive(:new).and_return(token_manager)
      allow(token_manager)
        .to receive(:issue_next_token)
        .and_return('abc.def.ghi')

      allow(InsertJournalEntryForm).to receive(:new)
        .and_raise(ArgumentError, "Validation failed: Date can't be blank")
    end

    it 'returns 422 and errors with next_token' do
      post path, params: params.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)

      body = JSON.parse(response.body)

      expect(body['errors']).to include("Validation failed: Date can't be blank")
      expect(body['next_token']).to eq('abc.def.ghi')
    end
  end

  describe 'authorization error' do
    before do
      allow_any_instance_of(TokenAuthenticator)
        .to receive(:authenticate!)
        .and_raise(UnauthorizedError)
    end

    it 'returns 401 without next_token' do
      post path, params: params.to_json, headers: headers

      expect(response).to have_http_status(:unauthorized)

      body = JSON.parse(response.body)

      expect(body['error']).to eq('unauthorized')
      expect(body).not_to have_key('next_token')
    end
  end

  describe 'business error (unbalanced journal)' do
    before do
      allow(TokenAuthenticator).to receive(:new).and_return(authenticator)
      allow(authenticator).to receive(:authenticate!).and_return(user)

      allow(TokenManager).to receive(:new).and_return(token_manager)
      allow(token_manager)
        .to receive(:issue_next_token)
        .and_return('abc.def.ghi')

      allow(InsertJournalEntryForm).to receive(:new).and_return(form)
      allow(form).to receive(:validated_data).and_return(validated_data)

      allow(Journals::InsertJournalEntryService)
        .to receive(:new)
        .and_return(service)

      allow(service).to receive(:call)
        .and_raise(Journals::InsertJournalEntry::UnbalancedJournal)
    end

    it 'returns 422 with error and next_token' do
      post path, params: params.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)

      body = JSON.parse(response.body)

      expect(body['error']).to eq('unbalanced_journal')
      expect(body['next_token']).to eq('abc.def.ghi')
    end
  end
end
