Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :items do
        # Undo / recycle bin. `trash` and `purge` are declared on the
        # collection so they land before the `:id` routes and aren't swallowed
        # by `show`.
        collection do
          get :trash
          delete :purge
        end
        member do
          post :restore
        end
      end

      resources :inventories, only: %i[index create update destroy] do
        resources :members, only: %i[index create update destroy],
                            controller: 'inventory_members'
      end

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
