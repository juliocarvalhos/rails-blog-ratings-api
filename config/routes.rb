Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :blog do
    namespace :api do
      resources :posts, only: [ :create ] do
        collection do
          get :top
          post :bulk_create
        end
      end
      resources :ratings, only: [ :create ] do
        collection do
          post :bulk_create
        end
      end

      resources :ips, only: [ :index ]
    end
  end
end
