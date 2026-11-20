class AddPaymentDateOverriddenToDirectDebitJournals < ActiveRecord::Migration[8.1]
  def change
    # 引き落とし日を手で変えたか。お買い物を修正したときに、変えた日を引き継ぐために使う
    add_column :direct_debit_journals, :payment_date_overridden, :boolean, null: false, default: false
  end
end
