# app/forms/update_direct_debit_date_form.rb

# 引き落とし日の変更（PUT /direct-debit-journals/:id）のリクエストを検証する。
class UpdateDirectDebitDateForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :payment_date, :date

  validates :payment_date, presence: true
end
