# frozen_string_literal: true

# Rubocop: disable Metrics/BlockLength
Rails.application.routes.draw do
  # Old domain → 301 to the new one. kamal-proxy's healthcheck doesn't send this host, so /up is unaffected.
  constraints(host: 'diety.rubydive.com') do
    match '(*path)', to: redirect(status: 301) { |_params, req| "https://asystentdiet.pl#{req.fullpath}" },
                     via: :all, format: false
  end

  ActiveAdmin.routes(self)
  root to: 'main#index'
  get 'style-guide', to: 'main#style_guide'
  get 'regulamin', to: 'main#terms', as: :terms
  get 'polityka-prywatnosci', to: 'main#privacy', as: :privacy
  get 'polityka-cookies', to: 'main#cookies_policy', as: :cookies_policy

  get 'up', to: 'health#show'

  mount MissionControl::Jobs::Engine, at: '/jobs'

  constraints lambda { |request|
                session_id = request.cookie_jar.signed[:session_id]
                session_id && Session.find_by(id: session_id)&.user&.admin?
              } do
                mount RailsPerformance::Engine, at: 'rails/performance'
              end

  resource :session, only: %i[new create destroy]
  resources :passwords, param: :token, only: %i[new create edit update]
  resources :registrations, only: %i[new create]
  resources :dietitian_waitlist_entries, path: 'dietitian-waitlist', only: %i[new create]

  resources :users, only: :update
  resources :product_substitutions, only: %i[index create destroy] do
    collection do
      post :import_pdf
      post :rematch
      post :expand_ai
    end
  end

  resources :product_categories,       only: %i[index update]
  resources :product_name_suggestions, only: %i[index update]
  resources :recipes, except: :show
  resources :diet_sets, only: %i[show create destroy]
  resources :meals, only: %i[create destroy]

  resources :diets, only: %i[edit update show new destroy] do
    member do
      patch :toggle_active
      post :reparse
    end
  end

  resource :diet_set_plans, only: %i[show create] do
    post 'toggle_shopping_bag/:id', to: 'diet_set_plans#toggle_shopping_bag', as: 'toggle_shopping_bag'
    post 'swap', to: 'diet_set_plans#swap', as: 'swap'
    patch 'servings', to: 'diet_set_plans#update_servings', as: 'servings'
    post 'cycle_product_replacement', to: 'diet_set_plans#cycle_product_replacement', as: 'cycle_product_replacement'
    post 'add_product_substitution', to: 'diet_set_plans#add_product_substitution', as: 'add_product_substitution'
    delete 'remove_product_substitution/:substitution_id', to: 'diet_set_plans#remove_product_substitution',
                                                           as: 'remove_product_substitution'
  end

  resources :meal_plans, only: :show do
    member do
      patch :toggle_eaten
    end
  end

  resource :shopping_cart, only: [:show]
  resources :shopping_cart_invitations, only: [:create] do
    member do
      patch :accept
      patch :reject
      patch :revoke
    end
  end
  resources :shopping_cart_items, only: [:destroy] do
    member do
      patch :toggle_bought
      patch :move
    end
    collection do
      post :undo
      delete :clear_bought
    end
  end
  resources :custom_cart_items, only: %i[create destroy] do
    member do
      patch :toggle_bought
    end
  end

  post 'diets', to: 'diets#create'
  get 'diets', to: 'diets#index'

  namespace :todoist do
    resources :projects, only: :index
  end
  post 'todoist', to: 'todoist#create', as: 'todoist_create'
  get 'auth_code', to: 'todoist#authorize', as: 'todoist_authorize'
  get 'receive_code', to: 'todoist#receive_code', as: 'todoist_receive_code'

  get 'profile', to: 'profile#show', as: 'profile'

  get 'upgrade', to: 'subscriptions#new', as: :upgrade
  post 'billing_portal', to: 'subscriptions#billing_portal', as: :billing_portal
  mount StripeEvent::Engine, at: '/stripe_webhooks'
end
# Rubocop: enable Metrics/BlockLength
