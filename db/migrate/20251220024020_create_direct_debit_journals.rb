class CreateDirectDebitJournals < ActiveRecord::Migration[8.1]
  def change
    create_table :direct_debit_journals do |t|
      # 元の仕訳
      t.references :original,
                   foreign_key: { to_table: :journals },
                   index: true

      # 引落仕訳
      t.references :direct_debit,
                   foreign_key: { to_table: :journals },
                   index: true

      t.references :user, foreign_key: true

      # PostgreSQL の CURRENT_TIMESTAMP を使う
      t.timestamps default: -> { "CURRENT_TIMESTAMP" }
    end
  end
end
