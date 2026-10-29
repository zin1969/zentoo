# frozen_string_literal: true

require "rails_helper"

RSpec.describe Journals::InsertJournalEntry do
  subject(:repository) { described_class.new }

  describe "#insert_journal_entry!" do
    let(:user) { create(:user, :masa) }
    let(:asset_account) { create(:asset_account, :cash, user: user) }
    let(:expense_account) { create(:expense_account, :food, user: user) }

    context "Case where the debit and credit totals balance (Normal scenario)" do
      let(:valid_journal_data) do
        {
          date: "2026-07-19",
          user_id: user.id,
          store_name: "ピザーラ",
          debits: [
            {
              element_type: 5,
              account_id: expense_account.id,
              amount: 1_000,
              item_name: "ピザ"
            }
          ],
          credits: [
            {
              element_type: 1,
              payment_method_type: 1,
              account_id: asset_account.id,
              amount: 1_000
            }
          ]
        }
      end

      it "Journal entries are successfully registered via a Postgres function and return the ID." do
        # --- act ---
        journal_id = repository.insert_journal_entry!(journal_data: valid_journal_data)

        # --- assert ---
        expect(journal_id).to be_present

        # 実際にDBにレコードが保存されているか、アップロードされたテストの項目を参考に検証
        journal = Journal.find(journal_id)
        expect(journal.journal_dt).to eq(Date.new(2026, 7, 19))
        expect(journal.store_name).to eq("ピザーラ")
        expect(journal.user_id).to eq(user.id)

        # 借方データの検証
        debit = journal.debits.first
        expect(debit.element_type).to eq(5)
        expect(debit.account_id).to eq(expense_account.id)
        expect(debit.amount.to_i).to eq(1_000)
        expect(debit.item_name).to eq("ピザ")
        expect(debit.user_id).to eq(user.id)

        # 貸方データの検証
        credit = journal.credits.first
        expect(credit.element_type).to eq(1)
        expect(credit.payment_method_type).to eq(1)
        expect(credit.account_id).to eq(asset_account.id)
        expect(credit.amount.to_i).to eq(1_000)
        expect(credit.user_id).to eq(user.id)
      end
    end

    context "When journal_data comes from InsertJournalEntryForm (includes ElementType/Amount value objects)" do
      let(:json_string) do
        {
          date: "2026-07-19",
          store_name: "ピザーラ",
          debits: [
            {
              element_type: 5,
              account_id: expense_account.id,
              amount: 1_000,
              item_name: "ピザ"
            }
          ],
          credits: [
            {
              element_type: 1,
              payment_method_type: 1,
              account_id: asset_account.id,
              amount: 1_000
            }
          ]
        }.to_json
      end

      # user_id はフォームでは受け取らず、controller が認証済みユーザーで補う
      let(:validated_data) { InsertJournalEntryForm.new(json_string).validated_data.merge(user_id: user.id) }

      it "serializes ElementType/Amount as raw values and registers the journal" do
        # --- act ---
        journal_id = repository.insert_journal_entry!(journal_data: validated_data)

        # --- assert ---
        expect(journal_id).to be_present

        journal = Journal.find(journal_id)
        expect(journal.journal_dt).to eq(Date.new(2026, 7, 19))
        expect(journal.store_name).to eq("ピザーラ")
        expect(journal.user_id).to eq(user.id)

        debit = journal.debits.first
        expect(debit.element_type).to eq(5)
        expect(debit.account_id).to eq(expense_account.id)
        expect(debit.amount.to_i).to eq(1_000)
        expect(debit.item_name).to eq("ピザ")
        expect(debit.user_id).to eq(user.id)

        credit = journal.credits.first
        expect(credit.element_type).to eq(1)
        expect(credit.payment_method_type).to eq(1)
        expect(credit.account_id).to eq(asset_account.id)
        expect(credit.amount.to_i).to eq(1_000)
        expect(credit.user_id).to eq(user.id)
      end
    end

    context "If the debit and credit totals do not match (error case)" do
      let(:invalid_journal_data) do
        {
          date: "2026-07-19",
          user_id: user.id,
          store_name: "ピザーラ",
          debits: [
            {
              element_type: 5,
              account_id: expense_account.id,
              amount: 1_000,
              item_name: "ピザ"
            }
          ],
          credits: [
            {
              element_type: 1,
              payment_method_type: 1,
              account_id: asset_account.id,
              amount: 900
            }
          ]
        }
      end

      it "UnbalancedJournal 例外が発生すること" do
        # --- act & assert ---
        # 期待通りのカスタム例外が発生するかどうかを検証
        expect {
          repository.insert_journal_entry!(journal_data: invalid_journal_data)
        }.to raise_error(Journals::InsertJournalEntry::UnbalancedJournal)
      end
    end

    describe "account availability" do
      def journal_data_for(debit_account:, credit_account:, debit_element: 5, credit_element: 1)
        {
          date: "2026-07-19",
          user_id: user.id,
          store_name: "ピザーラ",
          debits: [ { element_type: debit_element, account_id: debit_account.id, amount: 1_000, item_name: "ピザ" } ],
          credits: [ { element_type: credit_element, payment_method_type: 1, account_id: credit_account.id, amount: 1_000 } ]
        }
      end

      def insert_in_savepoint(data)
        ActiveRecord::Base.transaction(requires_new: true) do
          repository.insert_journal_entry!(journal_data: data)
        end
      end

      it "accepts a common expense account (user_id IS NULL)" do
        common_expense = create(:expense_account, :food, :common)

        journal_id = repository.insert_journal_entry!(
          journal_data: journal_data_for(debit_account: common_expense, credit_account: asset_account)
        )

        expect(Journal.find(journal_id).debits.first.account_id).to eq(common_expense.id)
      end

      it "rejects another user's expense account" do
        other_expense = create(:expense_account, :food, user: create(:user))

        expect {
          insert_in_savepoint(journal_data_for(debit_account: other_expense, credit_account: asset_account))
        }.to raise_error(Journals::InsertJournalEntry::AccountNotFound)

        expect(Journal.count).to eq(0)
      end

      it "rejects another user's asset account" do
        other_asset = create(:asset_account, :cash, user: create(:user))

        expect {
          insert_in_savepoint(journal_data_for(debit_account: expense_account, credit_account: other_asset))
        }.to raise_error(Journals::InsertJournalEntry::AccountNotFound)

        expect(Journal.count).to eq(0)
      end

      it "rejects another user's liability account" do
        other_liability = create(:liability_account, :jal, user: create(:user))

        expect {
          insert_in_savepoint(
            journal_data_for(debit_account: expense_account, credit_account: other_liability, credit_element: 2)
          )
        }.to raise_error(Journals::InsertJournalEntry::AccountNotFound)
      end

      it "rejects an account id that does not exist" do
        missing = build_stubbed(:asset_account, id: 0)

        expect {
          insert_in_savepoint(journal_data_for(debit_account: expense_account, credit_account: missing))
        }.to raise_error(Journals::InsertJournalEntry::AccountNotFound)
      end

      it "rejects an account whose element_type does not match its table" do
        # 資産科目の ID を、費用科目として指定する
        expect {
          insert_in_savepoint(
            journal_data_for(debit_account: asset_account, credit_account: asset_account, debit_element: 5)
          )
        }.to raise_error(Journals::InsertJournalEntry::AccountNotFound)
      end
    end
  end
end
