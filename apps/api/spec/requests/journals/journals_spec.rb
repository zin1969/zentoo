# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /journals', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) { { 'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}" } }
  let(:repository) { Journals::InsertJournalEntry.new }

  let!(:food) { create(:expense_account, :food, :common) }
  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }
  let!(:tcard) { create(:liability_account, :tcard, user: user) }

  before { create(:credit_card, :tcard, user: user, liability_account: tcard, bank_account: bank) }

  def register(date:, amount: 1_000, store_name: 'まいばすけっと', owner: user, credit: nil)
    repository.insert_journal_entry!(
      journal_data: {
        date: date,
        user_id: owner.id,
        store_name: store_name,
        debits: [ { element_type: 5, account_id: food.id, amount: amount, item_name: 'パン' } ],
        credits: [ credit || { element_type: 1, payment_method_type: 1, account_id: cash.id, amount: amount } ]
      }
    )
  end

  def get_journals(params = {})
    get '/journals', params: params, headers: headers
    JSON.parse(response.body)
  end

  it 'returns journals with debits, credits and account names' do
    id = register(date: '2026-10-09', amount: 108)

    body = get_journals

    expect(response).to have_http_status(:ok)
    expect(body).to include('page' => 1, 'per_page' => 50, 'total_count' => 1)
    expect(body['journals'].sole).to include(
      'id' => id,
      'journal_date' => '2026-10-09',
      'store_name' => 'まいばすけっと',
      'debits' => [ { 'element_type' => 5, 'account_id' => food.id, 'account_name' => '食費', 'item_name' => 'パン', 'amount' => 108,
          'tax_rate' => nil, 'tax_excluded_amount' => nil, 'tags' => [] } ],
      'credits' => [ { 'element_type' => 1, 'payment_method_type' => 1, 'account_id' => cash.id, 'account_name' => '現金', 'amount' => 108 } ],
      'original_journal_id' => nil,
      'direct_debit_journal_id' => nil
    )
  end

  it 'orders journals by date descending, then id descending' do
    older = register(date: '2026-10-01')
    newer = register(date: '2026-10-20')
    same_day_later = register(date: '2026-10-20')

    ids = get_journals['journals'].map { |j| j['id'] }

    expect(ids).to eq([ same_day_later, newer, older ])
  end

  it 'filters by the period, including both ends' do
    register(date: '2026-09-30')
    inside_start = register(date: '2026-10-01')
    inside_end = register(date: '2026-10-31')
    register(date: '2026-11-01')

    body = get_journals(from: '2026-10-01', to: '2026-10-31')

    expect(body['journals'].map { |j| j['id'] }).to contain_exactly(inside_start, inside_end)
    expect(body['total_count']).to eq(2)
  end

  it 'returns only the journals of the authenticated user' do
    mine = register(date: '2026-10-01')
    other = create(:user)
    other_cash = create(:asset_account, :cash, user: other)
    repository.insert_journal_entry!(
      journal_data: {
        date: '2026-10-01', user_id: other.id, store_name: 'other',
        debits: [ { element_type: 5, account_id: food.id, amount: 500, item_name: 'x' } ],
        credits: [ { element_type: 1, payment_method_type: 1, account_id: other_cash.id, amount: 500 } ]
      }
    )

    expect(get_journals['journals'].map { |j| j['id'] }).to eq([ mine ])
  end

  it 'paginates with 50 journals per page' do
    51.times { |i| register(date: Date.new(2026, 1, 1).next_day(i).to_s) }

    first = get_journals(page: 1)
    second = get_journals(page: 2)

    expect(first['journals'].size).to eq(50)
    expect(second['journals'].size).to eq(1)
    expect(first['total_count']).to eq(51)
    expect(second['page']).to eq(2)
    expect(second['journals'].sole['journal_date']).to eq('2026-01-01')
  end

  it 'returns an empty page beyond the last page' do
    register(date: '2026-10-01')

    body = get_journals(page: 5)

    expect(body['journals']).to eq([])
    expect(body['total_count']).to eq(1)
  end

  it 'links a credit card journal and its direct debit journal' do
    card_journal = register(
      date: '2026-10-09',
      credit: { element_type: 2, payment_method_type: 3, account_id: tcard.id, amount: 1_000 }
    )

    journals = get_journals['journals'].index_by { |j| j['id'] }
    debit_journal_id = (journals.keys - [ card_journal ]).sole

    expect(journals[card_journal]['direct_debit_journal_id']).to eq(debit_journal_id)
    expect(journals[card_journal]['original_journal_id']).to be_nil
    expect(journals[debit_journal_id]['original_journal_id']).to eq(card_journal)
    expect(journals[debit_journal_id]['journal_date']).to eq('2026-10-27')
    expect(journals[debit_journal_id]['credits'].sole['account_name']).to eq('三菱UFJ銀行 用賀出張所')
    expect(journals[debit_journal_id]['debits'].sole['account_name']).to eq('tcard')
  end

  describe 'searching' do
    def search_ids(params)
      get_journals(params)['journals'].map { |j| j['id'] }
    end

    def register_lines(date:, store_name:, lines:, credit_account: cash)
      debits = lines.map { |line| { element_type: 5, amount: 100, item_name: nil }.merge(line) }
      total = debits.sum { |debit| debit[:amount] }
      repository.insert_journal_entry!(
        journal_data: {
          date: date, user_id: user.id, store_name: store_name,
          debits: debits,
          credits: [ { element_type: 1, payment_method_type: 1, account_id: credit_account.id, amount: total } ]
        }
      )
    end

    describe 'by keyword (q)' do
      it 'finds journals whose store name or item name contains the keyword, ignoring case' do
        by_store = register(date: '2026-10-01', store_name: 'Book Off')
        by_item = register_lines(date: '2026-10-02', store_name: 'コンビニ',
                                 lines: [ { account_id: food.id, amount: 100, item_name: 'おにぎり' }, { account_id: food.id, amount: 200, item_name: 'NoteBOOK' } ])
        register(date: '2026-10-03', store_name: 'まいばすけっと')

        body = get_journals(q: ' book ')

        expect(body['journals'].map { |j| j['id'] }).to contain_exactly(by_store, by_item)
        expect(body['total_count']).to eq(2)
        # 一致しなかった明細も含めて、仕訳をまるごと返す
        expect(body['journals'].find { |j| j['id'] == by_item }['debits'].size).to eq(2)
      end

      it 'treats % and _ as plain characters' do
        percent = register(date: '2026-10-01', store_name: '100%オフ')
        register(date: '2026-10-02', store_name: '100円ショップ')
        underscore = register(date: '2026-10-03', store_name: 'a_b')
        register(date: '2026-10-04', store_name: 'axb')

        expect(search_ids(q: '%')).to eq([ percent ])
        expect(search_ids(q: '_')).to eq([ underscore ])
      end

      it 'ignores a blank keyword' do
        id = register(date: '2026-10-01')

        expect(search_ids(q: '  ')).to eq([ id ])
      end
    end

    describe 'by account (element_type and account_id)' do
      it 'finds journals using the account on either side' do
        bought_by_card = register(
          date: '2026-10-09',
          credit: { element_type: 2, payment_method_type: 3, account_id: tcard.id, amount: 1_000 }
        )
        register(date: '2026-10-10')

        ids = search_ids(element_type: 2, account_id: tcard.id)

        # カード払いの仕訳（貸方がカード）と、引き落とし仕訳（借方がカード）
        direct_debit_id = DirectDebitJournal.find_by!(original_id: bought_by_card).direct_debit_id
        expect(ids).to contain_exactly(bought_by_card, direct_debit_id)
      end

      it 'finds journals of the asset account' do
        by_cash = register(date: '2026-10-01')
        register_lines(date: '2026-10-02', store_name: 'x', lines: [ { account_id: food.id } ], credit_account: bank)

        expect(search_ids(element_type: 1, account_id: cash.id)).to eq([ by_cash ])
      end

      it 'includes the child accounts when a parent expense account is given' do
        eating_out = create(:expense_account, :eating_out, :common, parent: food)
        other = create(:expense_account, :entertainment, :common)
        on_parent = register(date: '2026-10-01')
        on_child = register_lines(date: '2026-10-02', store_name: 'x', lines: [ { account_id: eating_out.id } ])
        register_lines(date: '2026-10-03', store_name: 'x', lines: [ { account_id: other.id } ])

        expect(search_ids(element_type: 5, account_id: food.id)).to contain_exactly(on_parent, on_child)
        expect(search_ids(element_type: 5, account_id: eating_out.id)).to eq([ on_child ])
      end

      it 'includes the child accounts when a parent revenue account is given' do
        income = create(:revenue_account, :common, name: '給与所得')
        salary = create(:revenue_account, :salary, :common, parent: income)
        bonus = create(:revenue_account, :bonus, :common)
        incomes = Journals::IncomeJournals.new
        create_income = lambda do |account|
          incomes.create!(journal_date: Date.new(2026, 10, 25), asset_account_id: bank.id, revenue_account_id: account.id,
                          amount: 300_000, description: '会社', user_id: user.id)
        end
        on_salary = create_income.call(salary)
        create_income.call(bonus)

        expect(search_ids(element_type: 4, account_id: income.id)).to eq([ on_salary ])
      end

      it "finds nothing for another user's expense account" do
        register(date: '2026-10-01')
        others = create(:expense_account, :food, user: create(:user))
        child = create(:expense_account, :eating_out, :common, parent: others)
        register_lines(date: '2026-10-02', store_name: 'x', lines: [ { account_id: child.id } ])

        expect(search_ids(element_type: 5, account_id: others.id)).to eq([])
      end
    end

    describe 'by tag (tag_id)' do
      let!(:study) { create(:tag, :study, user: user) }

      it 'finds journals with a line tagged with the tag' do
        tagged = register_lines(date: '2026-10-01', store_name: '本屋',
                                lines: [ { account_id: food.id, tag_ids: [ study.id ] }, { account_id: food.id } ])
        register(date: '2026-10-02')

        expect(search_ids(tag_id: study.id)).to eq([ tagged ])
      end

      it "finds nothing for another user's tag" do
        register(date: '2026-10-01')

        expect(search_ids(tag_id: create(:tag, :study, user: create(:user)).id)).to eq([])
      end
    end

    it 'combines the conditions with the period (AND)' do
      study = create(:tag, :study, user: user)
      match = register_lines(date: '2026-10-05', store_name: '本屋', lines: [ { account_id: food.id, tag_ids: [ study.id ] } ])
      register_lines(date: '2026-09-05', store_name: '本屋', lines: [ { account_id: food.id, tag_ids: [ study.id ] } ])
      register_lines(date: '2026-10-06', store_name: 'コンビニ', lines: [ { account_id: food.id, tag_ids: [ study.id ] } ])
      register_lines(date: '2026-10-07', store_name: '本屋', lines: [ { account_id: food.id } ])
      register_lines(date: '2026-10-08', store_name: '本屋', lines: [ { account_id: food.id, tag_ids: [ study.id ] } ], credit_account: bank)

      body = get_journals(from: '2026-10-01', to: '2026-10-31', q: '本屋', element_type: 1, account_id: cash.id, tag_id: study.id)

      expect(body['journals'].map { |j| j['id'] }).to eq([ match ])
      expect(body['total_count']).to eq(1)
    end

    it 'returns 422 for invalid search conditions' do
      [ { account_id: 1 }, { element_type: 5 }, { element_type: 6, account_id: 1 }, { element_type: 5, account_id: 'x' }, { tag_id: 0 } ].each do |params|
        get_journals(params)

        expect(response).to have_http_status(:unprocessable_content), params.inspect
      end
    end
  end

  it 'does not put next_token in the body' do
    register(date: '2026-10-01')

    expect(get_journals).not_to have_key('next_token')
  end

  it 'returns 422 for an invalid period or page' do
    body = get_journals(from: '2026-10-31', to: '2026-10-01', page: 0)

    expect(response).to have_http_status(:unprocessable_content)
    expect(body['errors']).to be_present
  end

  it 'returns 401 without a token' do
    get '/journals'

    expect(response).to have_http_status(:unauthorized)
  end
end
