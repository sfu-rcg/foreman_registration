Rails.application.routes.draw do

  namespace :api, :defaults => {:format => 'json'} do
    post 'register'               => 'v2/registrations#register'
    post 'reset'                  => 'v2/registrations#reset'
    post 'decommission'           => 'v2/registrations#decommission'
    get  'registration_status'    => 'v2/registrations#registration_status'
    get  'reg_environments'       => 'v2/registrations#environments'
    get  'reg_hostgroups'         => 'v2/registrations#hostgroups'

    scope "(:apiv)", :module      => :v2,
                     :defaults    => { :apiv => 'v2' },
                     :apiv        => /v1|v2/,
                     :constraints => ApiConstraints.new(:version => 2) do

      resources :registrations, :only => [] do
        collection do
          post 'register'
          post 'reset'
          post 'decommission'
          get  'registration_status'
          get  'reg_environments'
          get  'reg_hostgroups'
        end
      end

    end
  end

end
