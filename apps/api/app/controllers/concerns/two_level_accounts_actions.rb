# app/controllers/concerns/two_level_accounts_actions.rb

# 親子 2 階層の共通科目（費用科目・収益科目）の一覧・追加・変更・削除。
# include するコントローラーは accounts_service（Accounts::TwoLevelAccountsService）と、
# エラーコードの接頭辞になる account_kind（"expense_account" など）を定義する。
module TwoLevelAccountsActions
  extend ActiveSupport::Concern

  included do
    include Authenticatable

    # 追加・変更・削除のエラーも、本文に新しいトークンを載せる（BFF が Cookie を更新する）
    rescue_from Accounts::TwoLevelAccountsService::NotFound do
      # 存在しない科目と他ユーザーの科目は区別しない
      render_error("#{account_kind}_not_found", :not_found)
    end

    rescue_from Accounts::TwoLevelAccountsService::InUse do
      render_error("#{account_kind}_in_use", :unprocessable_content)
    end

    rescue_from Accounts::TwoLevelAccountsService::HasChildren do
      render_error("#{account_kind}_has_children", :unprocessable_content)
    end

    rescue_from Accounts::TwoLevelAccountsService::InvalidParent do
      render_error("invalid_parent", :unprocessable_content)
    end

    rescue_from Accounts::TwoLevelAccountsService::DuplicateName do
      render_error("duplicate_account_name", :unprocessable_content)
    end
  end

  def index
    accounts = accounts_service.list(user: current_user).map do |item|
      {
        id: item.account.id,
        name: item.account.name,
        # 親の科目の ID（トップレベルの科目は null）
        parent_id: item.account.parent_id,
        # 仕訳で使われている。削除と親の付け替えができない
        in_use: item.in_use,
        # 子科目がある。削除できない
        has_children: item.has_children
      }
    end

    render json: accounts
  end

  def create
    form = TwoLevelAccountForm.new(params.permit(:name, :parent_id).to_h)
    return render_invalid(form) unless form.valid?

    account = accounts_service.create!(user: current_user, name: form.name, parent_id: form.parent_id)

    render json: { id: account.id, next_token: next_token }, status: :created
  end

  def update
    form = TwoLevelAccountForm.new(params.permit(:name, :parent_id).to_h)
    return render_invalid(form) unless form.valid?

    account = accounts_service.update!(user: current_user, id: params[:id], name: form.name, parent_id: form.parent_id)

    render json: { id: account.id, next_token: next_token }, status: :ok
  end

  # 削除は本文を返さない（新しいトークンは X-Next-Token ヘッダで返る）
  def destroy
    accounts_service.destroy!(user: current_user, id: params[:id])

    head :no_content
  end

  private

  def next_token
    response.headers[Authenticatable::NEXT_TOKEN_HEADER]
  end

  def render_invalid(form)
    render json: { errors: form.errors.full_messages, next_token: next_token }, status: :unprocessable_content
  end

  def render_error(code, status)
    render json: { error: code, next_token: next_token }, status: status
  end
end
