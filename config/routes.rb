Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :items

      post 'auth/signup', to: 'auth#signup'
      post 'auth/login',  to: 'auth#login'
      post 'auth/logout', to: 'auth#logout'
      post 'auth/verify', to: 'auth#verify'
      get  'auth/me',     to: 'auth#me'
    end
  end
end
