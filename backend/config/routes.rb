# frozen_string_literal: true

Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  mount_devise_token_auth_for 'Admin', at: 'auth', skip: [:omniauth_callbacks]
  post 'submissions/presigned_url', to: 'submissions#presigned_url'
  put 'submissions/:id/approve', to: 'submissions#approve'
  put 'submissions/:id/deny', to: 'submissions#deny'
  put 'submissions/:id/notes', to: 'submissions#notes'
  resources :submissions, only: [:index, :show, :create]
  resource :admin, only: [:show]
end
