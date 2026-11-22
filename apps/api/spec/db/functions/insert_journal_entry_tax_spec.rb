# frozen_string_literal: true

require "rails_helper"

# 外税のレシートで登録した明細の、税率と税抜の金額（表示のため。金額は amount の税込）
RSpec.describe "insert_journal_entry with tax" do
  let(:user) { create(:user, :masa) }
  let(:repository) { Journals::InsertJournalEntry.new }

  let!(:food) { create(:expense_account, :common, name: "食費") }
  let!(:goods) { create(:expense_account, :common, name: "日用品") }
  let!(:cash) { create(:asset_account, :cash, user: user) }

  def entry(debits:)
    {
      date: "2026-11-05", user_id: user.id, store_name: "スーパー",
      debits: debits,
      credits: [ { element_type: 1, payment_method_type: 1, account_id: cash.id, amount: debits.sum { |d| d[:amount] } } ]
    }
  end

  # DB 関数の RAISE でテスト全体のトランザクションが中断されないよう、savepoint の中で呼ぶ
  def register(data)
    ActiveRecord::Base.transaction(requires_new: true) { repository.insert_journal_entry!(journal_data: data) }
  end

  def tax_columns(journal_id)
    Journal.find(journal_id).debits.order(:id).map { |d| [ d.amount.to_i, d.tax_rate, d.tax_excluded_amount ] }
  end

  it "saves the tax rate and the tax-excluded amount of each line, with the tax-included amount" do
    # 食品 1,000 円（8%）と日用品 500 円（10%）の外税のレシート
    journal_id = register(entry(debits: [
      { element_type: 5, account_id: food.id, item_name: "肉", amount: 1_080, tax_rate: 8, tax_excluded_amount: 1_000 },
      { element_type: 5, account_id: goods.id, item_name: "洗剤", amount: 550, tax_rate: 10, tax_excluded_amount: 500 }
    ]))

    expect(tax_columns(journal_id)).to eq([ [ 1_080, 8, 1_000 ], [ 550, 10, 500 ] ])
  end

  it "leaves the columns empty for a tax-included line, as before" do
    journal_id = register(entry(debits: [ { element_type: 5, account_id: food.id, item_name: "パン", amount: 300 } ]))

    expect(tax_columns(journal_id)).to eq([ [ 300, nil, nil ] ])
  end

  it "accepts a rate typed by hand, such as a temporary 0%" do
    journal_id = register(entry(debits: [
      { element_type: 5, account_id: food.id, item_name: "米", amount: 2_000, tax_rate: 0, tax_excluded_amount: 2_000 }
    ]))

    expect(tax_columns(journal_id)).to eq([ [ 2_000, 0, 2_000 ] ])
  end

  it "rejects tax on a line that is not an expense" do
    bank = create(:asset_account, :mufg_yoga, user: user)
    data = entry(debits: [
      { element_type: 1, account_id: bank.id, item_name: "預入", amount: 1_100, tax_rate: 10, tax_excluded_amount: 1_000 }
    ])

    expect { register(data) }.to raise_error(Journals::InsertJournalEntry::TaxOnlyForExpenseDebits)
  end

  it "keeps only consistent values through the check constraints" do
    only_rate = entry(debits: [ { element_type: 5, account_id: food.id, item_name: "肉", amount: 1_080, tax_rate: 8 } ])
    over_amount = entry(debits: [
      { element_type: 5, account_id: food.id, item_name: "肉", amount: 1_080, tax_rate: 8, tax_excluded_amount: 1_100 }
    ])

    expect { register(only_rate) }.to raise_error(ActiveRecord::StatementInvalid, /debit_tax_columns_together/)
    expect { register(over_amount) }.to raise_error(ActiveRecord::StatementInvalid, /debit_tax_excluded_amount_range/)
  end

  it "keeps the tax columns sent again when the journal is replaced" do
    journal_id = register(entry(debits: [ { element_type: 5, account_id: food.id, item_name: "パン", amount: 300 } ]))

    new_id = ActiveRecord::Base.transaction(requires_new: true) do
      Journals::ReplaceJournalEntry.new.replace_journal_entry!(
        journal_id: journal_id,
        journal_data: entry(debits: [
          { element_type: 5, account_id: food.id, item_name: "パン", amount: 324, tax_rate: 8, tax_excluded_amount: 300 }
        ])
      )
    end

    expect(tax_columns(new_id)).to eq([ [ 324, 8, 300 ] ])
  end
end
