Rails.application.routes.draw do

  namespace :api, :defaults => {:format => 'json'} do
    get 'register' => 'v2/registrations#register'

    scope "(:apiv)", :module => :v2,
                     :defaults => {:apiv => 'v2'},
                     :apiv => /v1|v2/,
                     :constraints => ApiConstraints.new(:version => 2) do

      resources :registrations, :only => [] do
        collection do
          get 'register'
        end
      end
    end
  end

end
