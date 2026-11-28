# frozen_string_literal: true

require 'rails_helper'

# 現物株（M18）: 株の開始残高（POST /asset-opening-journals に shares）、売買（POST /stock-trades）、
# 銘柄ごとの株数・取得額（GET /stock-holdings）
RSpec.describe 'Stock trades', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) do
    {
      'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}",
      'Content-Type' => 'application/json'
    }
  end

  let!(:securities) { create(:asset_account, :securities, user: user) }
  let!(:toyota) { create(:asset_account, :toyota, user: user) }
  let!(:gain) { create(:revenue_account, :stock_gain, :common) }
  let!(:loss) { create(:expense_account, :stock_loss, :common) }

  before { create(:equity_account, :original_deposit, :common) }

  def body
    JSON.parse(response.body)
  end

  def register_opening(account: toyota, shares: 100, amount: 250_050, date: '2026-11-01')
    post '/asset-opening-journals',
         params: { journal_date: date, asset_type: 1, asset_account_id: account.id, amount: amount, shares: shares }.to_json,
         headers: headers
  end

  def trade(trade_type, date:, shares:, amount:, stock: toyota, from: securities)
    post '/stock-trades',
         params: { trade_type: trade_type, journal_date: date, stock_account_id: stock.id,
                   securities_account_id: from.id, shares: shares, amount: amount }.to_json,
         headers: headers
  end

  def holdings(date = '2026-12-31')
    get '/stock-holdings', params: { date: date }, headers: headers
    body
  end

  def toyota_holding(date = '2026-12-31')
    holdings(date)['holdings'].find { |holding| holding['account_id'] == toyota.id }
  end

  def entries(journal_id)
    journal = Journal.find(journal_id)
    debits = journal.debits.sort_by(&:id).map { |d| [ d.element_type.to_i, d.account_id, d.amount.to_i, d.shares ] }
    credits = journal.credits.sort_by(&:id).map { |c| [ c.element_type.to_i, c.account_id, c.amount.to_i, c.shares ] }

    [ debits, credits ]
  end

  describe 'opening balance with shares' do
    it 'registers the shares and the cost (shares x average price) against the original deposit' do
      register_opening

      expect(response).to have_http_status(:created)
      debit = Journal.find(body['journal_id']).debits.sole
      expect([ debit.account_id, debit.amount.to_i, debit.shares, debit.item_name ]).to eq([ toyota.id, 250_050, 100, '開始残高' ])
      expect(toyota_holding).to include('shares' => 100, 'cost' => 250_050, 'average_price' => 2500.5)
    end

    it 'returns 422 when the account is not an investment account' do
      register_opening(account: securities)

      expect(response).to have_http_status(:unprocessable_content)
      expect(body).to include('error' => 'shares_require_investment_account')
      expect(body['next_token']).to be_present
      expect(Journal.count).to eq(0)
    end

    it 'returns 422 for shares that are not a positive integer' do
      register_opening(shares: 0)

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['errors']).to include('Shares must be an integer between 1 and 2147483647')
    end

    it 'still registers an opening balance without shares' do
      register_opening(account: securities, shares: nil, amount: 30_000)

      expect(response).to have_http_status(:created)
      expect(Journal.find(body['journal_id']).debits.sole.shares).to be_nil
    end
  end

  describe 'POST /stock-trades' do
    before { register_opening }

    it 'buys: the stock gains shares and the cost including the fee, the securities account pays' do
      trade('buy', date: '2026-11-10', shares: 100, amount: 260_000)

      expect(response).to have_http_status(:created)
      expect(body['next_token']).to be_present
      expect(Journal.find(body['journal_id']).store_name).to eq('買い トヨタ 7203')
      expect(entries(body['journal_id'])).to eq([
        [ [ 1, toyota.id, 260_000, 100 ] ],
        [ [ 1, securities.id, 260_000, nil ] ]
      ])
      expect(Journal.find(body['journal_id']).credits.sole.payment_method_type).to eq(4)
      expect(toyota_holding).to include('shares' => 200, 'cost' => 510_050, 'average_price' => 2550.25)
    end

    it 'sells part at a gain: the cost goes down by the moving average and the difference is a gain' do
      trade('buy', date: '2026-11-10', shares: 100, amount: 260_000)
      trade('sell', date: '2026-11-20', shares: 50, amount: 140_000)

      expect(response).to have_http_status(:created)
      expect(Journal.find(body['journal_id']).store_name).to eq('売り トヨタ 7203')
      # 510,050 × 50 ÷ 200 = 127,512.5 → 127,513（四捨五入）
      expect(entries(body['journal_id'])).to eq([
        [ [ 1, securities.id, 140_000, nil ] ],
        [ [ 1, toyota.id, 127_513, 50 ], [ 4, gain.id, 12_487, nil ] ]
      ])
      expect(toyota_holding).to include('shares' => 150, 'cost' => 382_537)
    end

    it 'sells everything at a loss: the whole cost goes and the difference is a loss' do
      trade('sell', date: '2026-11-20', shares: 100, amount: 200_000)

      expect(response).to have_http_status(:created)
      expect(entries(body['journal_id'])).to eq([
        [ [ 1, securities.id, 200_000, nil ], [ 5, loss.id, 50_050, nil ] ],
        [ [ 1, toyota.id, 250_050, 100 ] ]
      ])
      expect(toyota_holding).to include('shares' => 0, 'cost' => 0, 'average_price' => nil)

      get '/monthly-expenses', params: { month: '2026-11' }, headers: headers
      expect(JSON.parse(response.body)['total']).to eq(50_050)
    end

    it 'sells at the cost without a gain or a loss line' do
      trade('sell', date: '2026-11-20', shares: 100, amount: 250_050)

      expect(entries(body['journal_id'])).to eq([
        [ [ 1, securities.id, 250_050, nil ] ],
        [ [ 1, toyota.id, 250_050, 100 ] ]
      ])
    end

    it 'uses the holdings up to the sale date' do
      trade('buy', date: '2026-11-25', shares: 100, amount: 300_000)
      trade('sell', date: '2026-11-20', shares: 150, amount: 400_000)

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('insufficient_shares')

      # 11/20 時点は開始残高の 100 株だけ。平均取得単価は 2,500.5 円
      trade('sell', date: '2026-11-20', shares: 10, amount: 30_000)
      expect(entries(body['journal_id'])[1].first).to eq([ 1, toyota.id, 25_005, 10 ])
    end

    it 'returns 422 when a later sale of the stock exists' do
      trade('sell', date: '2026-11-20', shares: 10, amount: 30_000)

      trade('buy', date: '2026-11-15', shares: 10, amount: 30_000)
      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('later_sale_exists')

      trade('sell', date: '2026-11-19', shares: 10, amount: 30_000)
      expect(body['error']).to eq('later_sale_exists')

      # 同じ日と後の日付なら登録できる
      trade('buy', date: '2026-11-20', shares: 10, amount: 30_000)
      expect(response).to have_http_status(:created)
    end

    it 'can register again after deleting the later sale' do
      trade('sell', date: '2026-11-20', shares: 10, amount: 30_000)
      delete "/journals/#{body['journal_id']}", headers: headers

      trade('buy', date: '2026-11-15', shares: 10, amount: 30_000)
      expect(response).to have_http_status(:created)
    end

    it 'returns 404 for an account of another user or of another type' do
      other = create(:user)

      trade('buy', date: '2026-11-10', shares: 1, amount: 1, stock: create(:asset_account, :toyota, user: other))
      expect(response).to have_http_status(:not_found)
      expect(body).to include('error' => 'stock_account_not_found')
      expect(body['next_token']).to be_present

      trade('buy', date: '2026-11-10', shares: 1, amount: 1, stock: securities)
      expect(body['error']).to eq('stock_account_not_found')

      trade('sell', date: '2026-11-10', shares: 1, amount: 1, from: create(:asset_account, :mufg_yoga, user: user))
      expect(response).to have_http_status(:not_found)
      expect(body['error']).to eq('securities_account_not_found')
    end

    it 'returns 422 when the gain or loss account is missing' do
      gain.destroy!
      trade('sell', date: '2026-11-20', shares: 10, amount: 90_000)
      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('stock_gain_account_not_found')

      loss.destroy!
      trade('sell', date: '2026-11-20', shares: 10, amount: 1_000)
      expect(body['error']).to eq('stock_loss_account_not_found')
      expect(Journal.count).to eq(1)
    end

    it 'returns 422 with errors for an invalid request' do
      post '/stock-trades', params: { trade_type: 'hold', shares: 0, amount: -1 }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['errors']).to contain_exactly(
        'Trade type must be buy or sell',
        "Journal date can't be blank",
        'Stock account must be an integer between 1 and 2147483647',
        'Securities account must be an integer between 1 and 2147483647',
        'Shares must be an integer between 1 and 2147483647',
        'Amount must be an integer between 1 and 2147483647'
      )
    end

    it 'shows the shares in the journal list and cannot be edited as a transfer' do
      trade('buy', date: '2026-11-10', shares: 100, amount: 260_000)
      buy_id = body['journal_id']

      get "/journals/#{buy_id}", headers: headers
      expect(body['debits'].sole).to include('account_name' => 'トヨタ 7203', 'shares' => 100)
      expect(body['credits'].sole).to include('account_name' => '証券口座', 'shares' => nil)

      put "/transfer-journals/#{buy_id}",
          params: { journal_date: '2026-11-10', from_type: 'asset', from_account_id: securities.id,
                    to_account_id: toyota.id, amount: 260_000 }.to_json,
          headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(body['error']).to eq('journal_not_editable')
      expect(Journal.find(buy_id).debits.sole.shares).to eq(100)
    end

    it 'records a dividend as an income into the securities account' do
      dividend = create(:revenue_account, :dividend, :common)

      post '/income-journals',
           params: { journal_date: '2026-11-28', asset_account_id: securities.id, revenue_account_id: dividend.id,
                     amount: 3_984 }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      # 配当は銘柄の株数・取得額を変えない
      expect(toyota_holding).to include('shares' => 100, 'cost' => 250_050)
    end

    it 'returns 401 without a token' do
      post '/stock-trades', params: {}.to_json, headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /stock-holdings' do
    it 'lists the stocks with shares as of the date, without investments that have no shares' do
      create(:asset_account, :nisa, user: user)
      sony = create(:asset_account, :sony, user: user)
      register_opening
      register_opening(account: sony, shares: 10, amount: 30_000, date: '2026-11-15')

      expect(holdings('2026-11-10')).to eq(
        'date' => '2026-11-10',
        'holdings' => [
          { 'account_id' => toyota.id, 'account_name' => 'トヨタ 7203', 'shares' => 100, 'cost' => 250_050, 'average_price' => 2500.5 }
        ],
        'total_cost' => 250_050
      )
      expect(holdings['holdings'].map { |holding| holding['account_id'] }).to eq([ toyota.id, sony.id ])
      expect(holdings['total_cost']).to eq(280_050)
    end

    it 'does not include stocks of other users' do
      other = create(:user)
      other_stock = create(:asset_account, :toyota, user: other)
      Journals::StockTrades.new.create_buy!(
        journal_date: Date.new(2026, 11, 1), stock_account_id: other_stock.id,
        securities_account_id: create(:asset_account, :securities, user: other).id, shares: 1, amount: 1, user_id: other.id
      )

      expect(holdings['holdings']).to eq([])
    end

    it 'returns 422 for an invalid date' do
      get '/stock-holdings', params: { date: '2026-13-01' }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 401 without a token' do
      get '/stock-holdings'

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
