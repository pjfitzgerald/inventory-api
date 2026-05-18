Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :items

      post 'auth/signup', to: 'auth#signup'
      post 'auth/login',  to: 'auth#login'
      post 'auth/logout', to: 'auth#logout'
      post 'auth/verify', to: 'auth#verify'
      post 'auth/request_password_reset', to: 'auth#request_password_reset'
      post 'auth/reset_password',         to: 'auth#reset_password'
      get  'auth/me',     to: 'auth#me'
    end
  end

  # Browser-facing HTML landing pages for links in verification / reset emails.
  get  'verify_email',   to: 'pages#verify_email'
  get  'reset_password', to: 'pages#reset_password_form', as: :reset_password
  # Form submission target; shares the path, so it isn't separately named.
  post 'reset_password', to: 'pages#reset_password', as: nil
end
