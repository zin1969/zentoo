# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Users
# system はパスワードなし（ログイン不可）。
User.find_or_create_by!(name: "system")

# masa がログイン用ユーザー。パスワードは SEED_USER_PASSWORD で指定する。
# 未指定の場合、開発・テスト環境のみ "password" を使い、本番ではエラーにする。
masa = User.find_or_create_by!(name: "masa")
if masa.password_digest.blank?
  masa.update!(
    password: ENV.fetch("SEED_USER_PASSWORD") do
      raise "SEED_USER_PASSWORD is required in production" if Rails.env.production?

      "password"
    end
  )
end

# Holidays（引き落とし日の営業日計算に使う）
load Rails.root.join("db/seeds/020_holidays.rb")

# Stores
Store.find_or_create_by!(name: "Aquavit")
Store.find_or_create_by!(name: "まいばすけっと")

# Accounts
load Rails.root.join("db/seeds/expense_accounts.rb")
load Rails.root.join("db/seeds/liability_accounts.rb")
load Rails.root.join("db/seeds/asset_accounts.rb")
load Rails.root.join("db/seeds/equity_accounts.rb")

# CreditCards
load Rails.root.join("db/seeds/credit_cards.rb")

# puts '== load seeds =='
#
# Dir[Rails.root.join('db/seeds/*.rb')].sort.each do |file|
#   puts "loading: #{File.basename(file)}"
#   require file
# end
