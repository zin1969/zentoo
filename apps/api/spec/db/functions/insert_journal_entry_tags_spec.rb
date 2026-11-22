# frozen_string_literal: true

require "rails_helper"

# お買い物の登録・修正で、明細ごとのタグ（debit_tags）も保存されることを確認する
RSpec.describe "insert_journal_entry with tags" do
  let(:user) { create(:user, :masa) }
  let(:repository) { Journals::InsertJournalEntry.new }

  let!(:books) { create(:expense_account, :common, name: "書籍") }
  let!(:snacks) { create(:expense_account, :common, name: "お菓子") }
  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:study) { create(:tag, :study, user: user) }
  let!(:fun) { create(:tag, :fun, user: user) }

  def entry(debits:, owner: user, credit_account: cash)
    {
      date: "2026-11-05", user_id: owner.id, store_name: "本屋",
      debits: debits,
      credits: [ { element_type: 1, payment_method_type: 1, account_id: credit_account.id, amount: debits.sum { |d| d[:amount] } } ]
    }
  end

  def line(account, amount, tag_ids: nil, item_name: "品")
    { element_type: 5, account_id: account.id, item_name: item_name, amount: amount }.tap do |d|
      d[:tag_ids] = tag_ids unless tag_ids.nil?
    end
  end

  # DB 関数の RAISE でテスト全体のトランザクションが中断されないよう、savepoint の中で呼ぶ
  def register(data)
    ActiveRecord::Base.transaction(requires_new: true) { repository.insert_journal_entry!(journal_data: data) }
  end

  def tags_by_item(journal_id)
    Journal.find(journal_id).debits.order(:id).map { |d| [ d.item_name, d.tags.order(:id).map(&:name) ] }
  end

  it "saves the tags of each line in the order the lines were sent" do
    journal_id = register(entry(debits: [
      line(books, 2_000, item_name: "参考書", tag_ids: [ study.id ]),
      line(snacks, 300, item_name: "グミ", tag_ids: [ fun.id ]),
      line(books, 800, item_name: "漫画")
    ]))

    expect(tags_by_item(journal_id)).to eq([ [ "参考書", [ "勉強" ] ], [ "グミ", [ "娯楽" ] ], [ "漫画", [] ] ])
  end

  it "accepts several tags on one line and ignores duplicates" do
    journal_id = register(entry(debits: [ line(books, 1_000, tag_ids: [ study.id, fun.id, study.id ]) ]))

    expect(tags_by_item(journal_id)).to eq([ [ "品", [ "勉強", "娯楽" ] ] ])
  end

  it "works without tag_ids, as before" do
    journal_id = register(entry(debits: [ line(books, 1_000) ]))

    expect(DebitTag.count).to eq(0)
    expect(Journal.find(journal_id).debits.count).to eq(1)
  end

  it "rejects another user's tag the same way as a missing one, and creates nothing" do
    other_tag = create(:tag, :study, user: create(:user))

    expect { register(entry(debits: [ line(books, 1_000, tag_ids: [ other_tag.id ]) ])) }
      .to raise_error(Journals::InsertJournalEntry::TagNotFound)
    expect { register(entry(debits: [ line(books, 1_000, tag_ids: [ 0 ]) ])) }
      .to raise_error(Journals::InsertJournalEntry::TagNotFound)
    expect(Journal.count).to eq(0)
  end

  it "rejects tags on a line that is not an expense" do
    bank = create(:asset_account, :mufg_yoga, user: user)
    data = entry(debits: [ { element_type: 1, account_id: bank.id, item_name: "預入", amount: 1_000, tag_ids: [ study.id ] } ])

    expect { register(data) }.to raise_error(Journals::InsertJournalEntry::TagsOnlyForExpenseDebits)
  end

  it "keeps the tags sent again when the journal is replaced" do
    journal_id = register(entry(debits: [ line(books, 1_000, tag_ids: [ study.id ]) ]))

    new_id = ActiveRecord::Base.transaction(requires_new: true) do
      Journals::ReplaceJournalEntry.new.replace_journal_entry!(
        journal_id: journal_id, journal_data: entry(debits: [ line(books, 1_500, tag_ids: [ fun.id ]) ])
      )
    end

    expect(tags_by_item(new_id)).to eq([ [ "品", [ "娯楽" ] ] ])
    expect(DebitTag.count).to eq(1)
  end

  it "removes the tags of deleted lines, and the lines of a deleted tag" do
    journal_id = register(entry(debits: [ line(books, 1_000, tag_ids: [ study.id, fun.id ]) ]))

    fun.destroy!
    expect(tags_by_item(journal_id)).to eq([ [ "品", [ "勉強" ] ] ])

    Journals::DeleteJournal.new.delete!(journal_id: journal_id, user_id: user.id)
    expect(DebitTag.count).to eq(0)
    expect(Tag.exists?(study.id)).to be(true)
  end
end
