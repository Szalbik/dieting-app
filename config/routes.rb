# frozen_string_literal: true

# Rubocop: disable Metrics/BlockLength
Rails.application.routes.draw do
  root to: 'main#index'

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

  resources :products, only: :index
  resources :users, only: :update

  resources :product_categories, only: %i[index edit update show]
  resources :diets, only: %i[edit update show new destroy]

  resource :diet_set_plans, only: %i[show create] do
    post 'toggle_shopping_bag/:id', to: 'diet_set_plans#toggle_shopping_bag', as: 'toggle_shopping_bag'
  end

  resource :shopping_cart, only: [:show]
  resources :shopping_cart_items, only: [:destroy] do
    collection do
      post :undo
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
