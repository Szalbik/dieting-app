# frozen_string_literal: true

require 'sidekiq/web'

Rails.application.routes.draw do
  get 'up', to: 'health#show'

  constraints lambda { |request|
                user_id = request.session[:user_id]
                user_id && User.find_by(id: user_id)&.admin?
              } do
    mount RailsPerformance::Engine, at: 'rails/performance'
    mount Sidekiq::Web => '/sidekiq'
  end

  # constraints lambda { |request| 
  #   user_id = request.session[:user_id]
  #   user_id.nil? && User.find_by(id: user_id).nil?
  # } do
  #   root to: 'main#index'
  # end 
  root to: 'meal_plans#show'

  resource :registration
  resource :session
  resource :password
  resource :password_reset

  resources :products, only: :index
  resources :users, only: :update

  resources :product_categories, only: %i[index edit update show]
  resources :diets, only: %i[edit update show new destroy]
  
  resource :meal_plans, only: :show
  
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
