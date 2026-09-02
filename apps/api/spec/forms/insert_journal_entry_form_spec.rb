# spec/forms/insert_journal_entry_form_spec.rb

require 'rails_helper'

RSpec.describe InsertJournalEntryForm do
  # インスタンス化のテスト用。エラーが起きないことを前提とする箇所で使用
  subject(:form) { described_class.new(json_string) }

  let(:date)       { '2026-07-19' }
  let(:user_id)    { 2 }
  let(:store_name) { 'ピザーラ' }
  
  let(:debits) do
    [
      {
        element_type: 5,
        account_id: 10051,
        amount: 1000,
        item_name: 'ピザ'
      }
    ]
  end

  let(:credits) do
    [
      {
        element_type: 1,
        payment_method_type: 1,
        account_id: 5,
        amount: 1000
      }
    ]
  end

  # テスト用のJSON文字列を動的に生成
  let(:json_string) do
    {
      date: date,
      user_id: user_id,
      store_name: store_name,
      debits: debits,
      credits: credits
    }.to_json
  end

  describe 'initialization and validations' do
    context 'when all parameters are valid' do
      it 'initializes successfully without raising an error' do
        expect { form }.not_to raise_error
      end

      it 'saves the casted data to validated_data' do
        # 期待通り、自動でDateオブジェクトや独自型に変換されていることを検証
        expect(form.validated_data[:date]).to eq(Date.new(2026, 7, 19))
        expect(form.validated_data[:user_id]).to eq(2)
        expect(form.validated_data[:store_name]).to eq('ピザーラ')
        
        # 配列の中身が ElementType や Amount に変換されていることを検証
        first_debit = form.validated_data[:debits].first
        expect(first_debit[:element_type]).to be_an(ElementType)
        expect(first_debit[:amount]).to be_an(Amount)

        first_credit = form.validated_data[:credits].first
        expect(first_credit[:element_type]).to be_an(ElementType)
        expect(first_credit[:amount]).to be_an(Amount)
      end
    end

    context 'with invalid JSON format' do
      let(:json_string) { '{ invalid json }' }

      it 'raises an ArgumentError for invalid JSON' do
        expect { described_class.new(json_string) }.to raise_error(
          ArgumentError, 'Invalid JSON format'
        )
      end
    end

    context 'when date is missing' do
      let(:date) { nil }

      it 'raises a validation error' do
        expect { described_class.new(json_string) }.to raise_error(
          ArgumentError, /Validation failed: Date can't be blank/
        )
      end
    end

    context 'when user_id is missing' do
      let(:user_id) { nil }

      it 'raises a validation error' do
        expect { described_class.new(json_string) }.to raise_error(
          ArgumentError, /Validation failed: User can't be blank/
        )
      end
    end

    context 'when debits is blank' do
      let(:debits) { [] }

      it 'raises a validation error' do
        expect { described_class.new(json_string) }.to raise_error(
          ArgumentError, /Validation failed: Debits can't be blank/
        )
      end
    end

    context 'when credits is blank' do
      let(:credits) { [] }

      it 'raises a validation error' do
        expect { described_class.new(json_string) }.to raise_error(
          ArgumentError, /Validation failed: Credits can't be blank/
        )
      end
    end

    context 'when nested debit elements are invalid' do
      let(:debits) do
        [
          {
            element_type: nil, # 必須エラーかつ型エラーを誘発
            account_id: 10051,
            amount: 1000
          }
        ]
      end

      it 'raises a validation error with index information' do
        expect { described_class.new(json_string) }.to raise_error(ArgumentError) do |error|
          expect(error.message).to match(/Debits\[0\]: Element type must be an ElementType/)
        end
      end
    end

    context 'when nested credit elements are invalid' do
      let(:credits) do
        [
          {
            element_type: 1,
            account_id: 5,
            amount: nil # 必須エラーかつ型エラーを誘発
          }
        ]
      end

      it 'raises a validation error with index information' do
        expect { described_class.new(json_string) }.to raise_error(ArgumentError) do |error|
          expect(error.message).to match(/Credits\[0\]: Amount must be an Amount/)
        end
      end
    end
  end
end
