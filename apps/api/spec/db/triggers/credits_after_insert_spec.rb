# frozen_string_literal: true

require "rails_helper"

# credits への INSERT 後に、クレジットカード払いの引き落とし仕訳が自動で作られることを確認する。
# トリガーは直接呼ばず、仕訳登録（insert_journal_entry）を通して副作用を検証する。
RSpec.describe "credits_after_insert trigger" do
  let(:user) { create(:user, :masa) }
  let(:repository) { Journals::InsertJournalEntry.new }

  let!(:expense) { create(:expense_account, :eating_out, :common) }
  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:jal) { create(:liability_account, :jal, user: user) }
  let!(:tcard) { create(:liability_account, :tcard, user: user) }

  before do
    create(:credit_card, :jal, user: user, liability_account: jal, bank_account: bank)
    create(:credit_card, :tcard, user: user, liability_account: tcard, bank_account: bank)
  end

  def register(date:, credit:, debits: [ { item_name: "バー", amount: 3_300 } ])
    repository.insert_journal_entry!(
      journal_data: {
        date: date,
        user_id: user.id,
        store_name: "Aquavit 001",
        debits: debits.map { |d| d.merge(element_type: 5, account_id: expense.id) },
        credits: [ credit.merge(amount: debits.sum { |d| d[:amount] }) ]
      }
    )
  end

  def card_payment(account)
    { element_type: 2, payment_method_type: 3, account_id: account.id }
  end

  context "when paying by credit card" do
    let!(:journal_id) { register(date: "2025-11-09", credit: card_payment(tcard), debits: [ { item_name: "バー", amount: 3_740 } ]) }
    let(:direct_debit) { DirectDebitJournal.find_by!(original_id: journal_id) }
    let(:debit_journal) { Journal.find(direct_debit.direct_debit_id) }

    it "creates a journal on the payment date, copying store name and user" do
      expect(debit_journal.journal_dt).to eq(Date.new(2025, 11, 27))
      expect(debit_journal.store_name).to eq("Aquavit 001")
      expect(debit_journal.user_id).to eq(user.id)
      expect(direct_debit.user_id).to eq(user.id)
    end

    it "debits the card liability and credits the bank account" do
      debit = debit_journal.debits.sole
      expect([ debit.element_type, debit.account_id, debit.item_name, debit.amount.to_i ])
        .to eq([ 2, tcard.id, "バー", 3_740 ])

      credit = debit_journal.credits.sole
      expect([ credit.element_type, credit.payment_method_type, credit.account_id, credit.amount.to_i ])
        .to eq([ 1, 2, bank.id, 3_740 ])
    end

    it "does not create a second direct debit for the generated journal" do
      expect(DirectDebitJournal.count).to eq(1)
      expect(Journal.count).to eq(2)
    end
  end

  it "joins the item names of the original journal" do
    journal_id = register(
      date: "2025-11-09",
      credit: card_payment(tcard),
      debits: [ { item_name: "ビール", amount: 1_000 }, { item_name: "つまみ", amount: 800 } ]
    )

    debit_journal = Journal.find(DirectDebitJournal.find_by!(original_id: journal_id).direct_debit_id)

    expect(debit_journal.debits.sole.item_name).to eq("ビール,つまみ")
    expect(debit_journal.debits.sole.amount.to_i).to eq(1_800)
  end

  it "does not create a direct debit for cash payments" do
    register(date: "2025-11-09", credit: { element_type: 1, payment_method_type: 1, account_id: cash.id })

    expect(DirectDebitJournal.count).to eq(0)
    expect(Journal.count).to eq(1)
  end

  it "raises CreditCardSettingNotFound and creates nothing when the card has no setting" do
    card_without_setting = create(:liability_account, :paypay, user: user)

    expect {
      ActiveRecord::Base.transaction(requires_new: true) do
        register(date: "2025-11-09", credit: card_payment(card_without_setting))
      end
    }.to raise_error(Journals::InsertJournalEntry::CreditCardSettingNotFound)

    expect(Journal.count).to eq(0)
  end
end
