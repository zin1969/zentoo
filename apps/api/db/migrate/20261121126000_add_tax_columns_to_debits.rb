class AddTaxColumnsToDebits < ActiveRecord::Migration[8.1]
  def change
    # 外税のレシートで登録した明細の、税率（整数の %）と税抜の金額。表示のために持つ。
    # 残高・集計は今までどおり amount（税込）で計算する。内税で登録した明細はどちらも NULL
    add_column :debits, :tax_rate, :integer
    add_column :debits, :tax_excluded_amount, :integer

    add_check_constraint :debits, "(tax_rate IS NULL) = (tax_excluded_amount IS NULL)",
                         name: "debit_tax_columns_together"
    add_check_constraint :debits, "tax_rate IS NULL OR tax_rate BETWEEN 0 AND 100",
                         name: "debit_tax_rate_range"
    add_check_constraint :debits, "tax_excluded_amount IS NULL OR tax_excluded_amount BETWEEN 0 AND amount",
                         name: "debit_tax_excluded_amount_range"
  end
end
