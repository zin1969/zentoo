Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
  post "/login", to: "sessions#create"

  get "/journals", to: "journals/journals#index"
  get "/journals/:id", to: "journals/journals#show", constraints: { id: /\d+/ }
  delete "/journals/:id", to: "journals/journals#destroy", constraints: { id: /\d+/ }
  get "/account-balances", to: "reports/account_balances#index"
  get "/monthly-expenses", to: "reports/monthly_expenses#index"
  post "/asset-opening-journals", to: "journals/asset_opening_journals#create"
  post "/liability-opening-journals", to: "journals/liability_opening_journals#create"
  post "/journal-entries", to: "journals/journal_entries#create"
  put "/journal-entries/:id", to: "journals/journal_entries#update", constraints: { id: /\d+/ }
  post "/cash-deposit-journals", to: "journals/cash_deposit_journals#create"
  put "/direct-debit-journals/:id", to: "journals/direct_debit_journals#update", constraints: { id: /\d+/ }

  get "/asset-accounts", to: "accounts/asset_accounts#index"
  post "/asset-accounts", to: "accounts/asset_accounts#create"
  put "/asset-accounts/:id", to: "accounts/asset_accounts#update", constraints: { id: /\d+/ }
  delete "/asset-accounts/:id", to: "accounts/asset_accounts#destroy", constraints: { id: /\d+/ }
  get "/expense-accounts", to: "accounts/expense_accounts#index"
  post "/expense-accounts", to: "accounts/expense_accounts#create"
  put "/expense-accounts/:id", to: "accounts/expense_accounts#update", constraints: { id: /\d+/ }
  delete "/expense-accounts/:id", to: "accounts/expense_accounts#destroy", constraints: { id: /\d+/ }
  get "/liability-accounts", to: "accounts/liability_accounts#index"

  get "/credit-cards", to: "accounts/credit_cards#index"
  post "/credit-cards", to: "accounts/credit_cards#create"
  put "/credit-cards/:id", to: "accounts/credit_cards#update", constraints: { id: /\d+/ }
  delete "/credit-cards/:id", to: "accounts/credit_cards#destroy", constraints: { id: /\d+/ }
end
