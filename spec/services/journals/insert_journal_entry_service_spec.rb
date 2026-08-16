# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Journals::InsertJournalEntryService do
  describe '#call' do
    let(:repository) { instance_double(Journals::InsertJournalEntry) }
    let(:service) { described_class.new(repository: repository) }

    let(:journal_data) do
      {
        date: '2026-07-19',
        user_id: 1,
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

    context 'when repository succeeds' do
      it 'calls repository within a transaction and returns journal_id' do
        allow(repository).to receive(:insert_journal_entry!)
          .and_return(456)

        result = service.call(
          journal_data: journal_data
        )

        expect(repository).to have_received(:insert_journal_entry!).with(
          journal_data: journal_data
        )

        expect(result).to eq(456)
      end
    end

    context 'when repository raises UnbalancedJournal' do
      it 'propagates the exception' do
        allow(repository).to receive(:insert_journal_entry!)
          .and_raise(Journals::InsertJournalEntry::UnbalancedJournal)

        expect {
          service.call(
            journal_data: journal_data
          )
        }.to raise_error(Journals::InsertJournalEntry::UnbalancedJournal)
      end
    end
  end
end
