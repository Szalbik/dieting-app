# frozen_string_literal: true

# Rubocop: disable Metrics/BlockLength
Rails.application.routes.draw do
  ActiveAdmin.routes(self)
  root to: 'main#index'
  get 'style-guide', to: 'main#style_guide'

  get 'up', to: 'health#show'

  mount MissionControl::Jobs::Engine, at: '/jobs'

  constraints lambda { |request|
                user_id = request.session[:user_id]
                user_id && User.find_by(id: user_id)&.admin?
              } do
                mount RailsPerformance::Engine, at: 'rails/performance'
              end

  resource :session, only: %i[new create destroy]
  resources :passwords, param: :token, only: %i[new create edit update]
  resources :registrations, only: %i[new create]
  resources :dietitian_waitlist_entries, path: 'dietitian-waitlist', only: %i[new create]

  resources :products, only: :index
  resources :users, only: :update
  resources :product_substitutions, only: %i[index create destroy] do
    collection do
      post :import_pdf
      post :rematch
      post :expand_ai
    end
  end

  resources :product_categories,       only: %i[index edit update show]
  resources :product_name_suggestions, only: %i[index update]
  resources :diets, only: %i[edit update show new destroy] do
    member do
      patch :toggle_active
      post :reparse
    end
  end

  resource :diet_set_plans, only: %i[show create] do
    post 'toggle_shopping_bag/:id', to: 'diet_set_plans#toggle_shopping_bag', as: 'toggle_shopping_bag'
    post 'swap', to: 'diet_set_plans#swap', as: 'swap'
    post 'replace_product', to: 'diet_set_plans#replace_product', as: 'replace_product'
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
    end
    collection do
      post :undo
    end
  end
  resources :custom_cart_items, only: %i[create destroy] do
    member do
      patch :toggle_bought
    end
  end

  get 'diets/:id/search', to: 'diets#search', as: 'diet_search'
  post 'diets', to: 'diets#create'
  get 'diets', to: 'diets#index'
  get 'diets/:id/load_pdf', to: 'diets#load_pdf', as: 'load_pdf'

  namespace :todoist do
    resources :projects, only: :index
  end
  post 'todoist', to: 'todoist#create', as: 'todoist_create'
  get 'auth_code', to: 'todoist#authorize', as: 'todoist_authorize'
  get 'receive_code', to: 'todoist#receive_code', as: 'todoist_receive_code'

  get 'profile', to: 'profile#show', as: 'profile'
end
# Rubocop: enable Metrics/BlockLength
