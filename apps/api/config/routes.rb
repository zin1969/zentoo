Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
  post "/login", to: "sessions#create"

  get "/journals", to: "journals/journals#index"
  get "/account-balances", to: "reports/account_balances#index"
  get "/monthly-expenses", to: "reports/monthly_expenses#index"
  post "/asset-opening-journals", to: "journals/asset_opening_journals#create"
  post "/journal-entries", to: "journals/journal_entries#create"
  post "/cash-deposit-journals", to: "journals/cash_deposit_journals#create"

  get "/asset-accounts", to: "accounts/asset_accounts#index"
  get "/expense-accounts", to: "accounts/expense_accounts#index"
  get "/liability-accounts", to: "accounts/liability_accounts#index"
end
