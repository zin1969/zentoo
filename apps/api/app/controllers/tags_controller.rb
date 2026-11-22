# app/controllers/tags_controller.rb

class TagsController < ApplicationController
  include Authenticatable

  # 追加・変更・削除のエラーも、本文に新しいトークンを載せる（BFF が Cookie を更新する）
  rescue_from Tags::TagsService::NotFound do
    # 存在しないタグと他ユーザーのタグは区別しない
    render_error("tag_not_found", :not_found)
  end

  rescue_from Tags::TagsService::DuplicateName do
    render_error("duplicate_tag_name", :unprocessable_content)
  end

  def index
    tags = Tags::TagsService.new.list(user: current_user).map do |item|
      # usage_count: タグが付いている明細の数
      { id: item.tag.id, name: item.tag.name, usage_count: item.usage_count }
    end

    render json: tags
  end

  # お買い物登録の画面から、その場でタグを作るときにも使う
  def create
    form = TagForm.new(params.permit(:name).to_h)
    return render_invalid(form) unless form.valid?

    tag = Tags::TagsService.new.create!(user: current_user, name: form.name)

    render json: { id: tag.id, name: tag.name, next_token: next_token }, status: :created
  end

  def update
    form = TagForm.new(params.permit(:name).to_h)
    return render_invalid(form) unless form.valid?

    tag = Tags::TagsService.new.update!(user: current_user, id: params[:id], name: form.name)

    render json: { id: tag.id, name: tag.name, next_token: next_token }, status: :ok
  end

  # 削除は本文を返さない（新しいトークンは X-Next-Token ヘッダで返る）
  def destroy
    Tags::TagsService.new.destroy!(user: current_user, id: params[:id])

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
