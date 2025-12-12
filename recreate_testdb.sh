#!/bin/bash

DB_NAME="testdb"
DB_USER="$(whoami)"   # 必要に応じて postgres 等に変更

echo "Dropping database: $DB_NAME (if exists)"
dropdb --if-exists -U "$DB_USER" "$DB_NAME"

echo "Creating database: $DB_NAME"
createdb -U "$DB_USER" "$DB_NAME"

echo "Creating functions and tables"
psql -U "$DB_USER" -d "$DB_NAME" -f update_updated_at_with_current_timestamp.sql

psql -U "$DB_USER" -d "$DB_NAME" -f create_table_holidays.sql
psql -U "$DB_USER" -d "$DB_NAME" -f create_table_users.sql
psql -U "$DB_USER" -d "$DB_NAME" -f create_table_stores.sql
psql -U "$DB_USER" -d "$DB_NAME" -f create_table_expense_accounts.sql
psql -U "$DB_USER" -d "$DB_NAME" -f create_table_liability_accounts.sql
psql -U "$DB_USER" -d "$DB_NAME" -f create_table_asset_accounts.sql
psql -U "$DB_USER" -d "$DB_NAME" -f create_table_credit_cards.sql
psql -U "$DB_USER" -d "$DB_NAME" -f create_table_journals.sql
psql -U "$DB_USER" -d "$DB_NAME" -f create_table_direct_debit_journals.sql
psql -U "$DB_USER" -d "$DB_NAME" -f create_table_debits.sql
psql -U "$DB_USER" -d "$DB_NAME" -f create_table_credits.sql

psql -U "$DB_USER" -d "$DB_NAME" -f get_next_business_day.sql
psql -U "$DB_USER" -d "$DB_NAME" -f generate_direct_debit_journal.sql
psql -U "$DB_USER" -d "$DB_NAME" -f generate_make_a_cash_deposit_journal.sql

psql -U "$DB_USER" -d "$DB_NAME" -f alter_table_add_trigger_credits.sql

echo "Loading initial data..."
psql -U "$DB_USER" -d "$DB_NAME" -f init_data.sql
psql -U "$DB_USER" -d "$DB_NAME" -f test/use_cash.sql
psql -U "$DB_USER" -d "$DB_NAME" -f test/use_credit_only.sql
psql -U "$DB_USER" -d "$DB_NAME" -f test/make_a_cash_deposit.sql

echo "Done."
