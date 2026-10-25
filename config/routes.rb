Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    resources :books, only: %i[index create destroy] do
      resources :borrowings, only: %i[index], module: :books
    end
    resources :borrowings, only: %i[create] do
      member { patch :return }
    end
  end
end
