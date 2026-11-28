# app/controllers/journals/stock_trades_controller.rb

module Journals
  class StockTradesController < ApplicationController
    # 存在しない口座と他ユーザーの口座、種別の違う口座は区別しない
    rescue_from Journals::StockTrades::StockAccountNotFound do
      render_error("stock_account_not_found", :not_found)
    end

    rescue_from Journals::StockTrades::SecuritiesAccountNotFound do
      render_error("securities_account_not_found", :not_found)
    end

    # 売る日に持っている株数より多くは売れない
    rescue_from Journals::StockTrades::InsufficientShares do
      render_error("insufficient_shares", :unprocessable_content)
    end

    # その銘柄に後の日付の売りがあると、その売りの取得額（移動平均）が合わなくなる
    rescue_from Journals::StockTrades::LaterSaleExists do
      render_error("later_sale_exists", :unprocessable_content)
    end

    # 売却益・売却損の科目（名前で探す）が、管理画面で名前を変えられたか削除された
    rescue_from Journals::StockTrades::StockGainAccountNotFound do
      render_error("stock_gain_account_not_found", :unprocessable_content)
    end

    rescue_from Journals::StockTrades::StockLossAccountNotFound do
      render_error("stock_loss_account_not_found", :unprocessable_content)
    end

    # 株の売買の仕訳を登録する。修正はできない（削除して登録し直す）
    def create
      authenticate

      form = StockTradeForm.new(
        params.permit(:trade_type, :journal_date, :stock_account_id, :securities_account_id, :shares, :amount).to_h
      )

      unless form.valid?
        return render json: { errors: form.errors.full_messages, next_token: @next_token }, status: :unprocessable_content
      end

      # 持ち主は認証済みユーザーなので、user_id は受け取らない
      journal_id = Journals::StockTradeService.new.create(
        trade_type: form.trade_type,
        journal_date: form.journal_date,
        stock_account_id: form.stock_account_id,
        securities_account_id: form.securities_account_id,
        shares: form.shares,
        amount: form.amount,
        user_id: @user.id
      )

      render json: { journal_id: journal_id, next_token: @next_token }, status: :created
    end

    private

    # 書き込み API なので、新しいトークンは本文の next_token で返す（401 を除く）
    def authenticate
      token = request.headers["Authorization"]&.split(" ")&.last
      @user = TokenAuthenticator.new.authenticate!(token)
      @next_token = TokenManager.new.issue_next_token(@user)
    end

    def render_error(code, status)
      render json: { error: code, next_token: @next_token }, status: status
    end
  end
end
