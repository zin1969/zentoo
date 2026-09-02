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
User.find_or_create_by!(name: "system")
User.find_or_create_by!(name: "masa")

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
