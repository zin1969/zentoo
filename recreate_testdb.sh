#!/bin/bash

DB_NAME="testdb"
DB_USER="$(whoami)"   # 必要に応じて postgres 等に変更

echo "Dropping database: $DB_NAME (if exists)"
dropdb --if-exists -U "$DB_USER" "$DB_NAME"

echo "Creating database: $DB_NAME"
createdb -U "$DB_USER" "$DB_NAME"

echo "Creating functions and tables"
psql -U "$DB_USER" -d "$DB_NAME" -f update_updated_at_with_current_timestamp.sql
psql -U "$DB_USER" -d "$DB_NAME" -f get_next_business_day.sql
psql -U "$DB_USER" -d "$DB_NAME" -f create_table_holidays.sql
psql -U "$DB_USER" -d "$DB_NAME" -f create_table_users.sql
psql -U "$DB_USER" -d "$DB_NAME" -f create_table_stores.sql
psql -U "$DB_USER" -d "$DB_NAME" -f create_table_journals.sql

echo "Loading initial data..."
psql -U "$DB_USER" -d "$DB_NAME" -f init_data.sql

echo "Done."
