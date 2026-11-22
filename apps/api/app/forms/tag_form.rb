# app/forms/tag_form.rb

# タグの追加・名前の変更（POST /tags、PUT /tags/:id）のリクエストを検証する。
class TagForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  MAX_NAME_LENGTH = 30

  attribute :name, :string

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }

  def name=(value)
    super(value.is_a?(String) ? value.strip : value)
  end
end
