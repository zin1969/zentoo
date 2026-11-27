class AddTransferToRecurringEntries < ActiveRecord::Migration[8.1]
  # 決まった収支に kind = 3（振替）を足す。借方は入金先の口座（資産）、貸方は出金元の口座かカード（資産か負債）。
  # 入金先は今までの debit_account_id を使うので、列は増やさない。
  # 振替の仕訳を修正（作り直し）しても、回の記録が新しい仕訳に付いたままになるようにする。
  # down は、振替の決まった収支が残っていると制約の追加に失敗する（消してから戻す）。
  # replace_transfer_journal は CREATE OR REPLACE なので、down では以前の定義へ戻さない（回の記録を付け直すだけで、振替の動きは同じ）
  def up
    execute <<~SQL
      ALTER TABLE recurring_entries DROP CONSTRAINT recurring_entry_kind;
      ALTER TABLE recurring_entries
        ADD CONSTRAINT recurring_entry_kind CHECK (kind IN (1, 2, 3));

      ALTER TABLE recurring_entries DROP CONSTRAINT recurring_entry_credit_element_type;
      ALTER TABLE recurring_entries
        ADD CONSTRAINT recurring_entry_credit_element_type CHECK (
          (kind = 1 AND credit_element_type IN (1, 2))
          OR (kind = 2 AND credit_element_type = 4)
          OR (kind = 3 AND credit_element_type IN (1, 2))
        );
    SQL

    create_function 'journals/replace_transfer_journal.sql'
  end

  def down
    execute <<~SQL
      ALTER TABLE recurring_entries DROP CONSTRAINT recurring_entry_credit_element_type;
      ALTER TABLE recurring_entries
        ADD CONSTRAINT recurring_entry_credit_element_type CHECK (
          (kind = 1 AND credit_element_type IN (1, 2))
          OR (kind = 2 AND credit_element_type = 4)
        );

      ALTER TABLE recurring_entries DROP CONSTRAINT recurring_entry_kind;
      ALTER TABLE recurring_entries
        ADD CONSTRAINT recurring_entry_kind CHECK (kind IN (1, 2));
    SQL
  end
end
