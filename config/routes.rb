Rails.application.routes.draw do

  namespace :api, :defaults => {:format => 'json'} do
    post 'register'               => 'v2/registrations#register'
    post 'decommission'           => 'v2/registrations#decommission'
    get  'environment_list'       => 'v2/registrations#environment_list'
    get  'environment_id_by_name' => 'v2/registrations#environment_id_by_name'
    get  'hostgroup_list'         => 'v2/registrations#hostgroup_list'
    get  'hostgroup_id_by_name'   => 'v2/registrations#hostgroup_id_by_name'

    scope "(:apiv)", :module => :v2,
                     :defaults => {:apiv => 'v2'},
                     :apiv => /v1|v2/,
                     :constraints => ApiConstraints.new(:version => 2) do

      resources :registrations, :only => [] do
        collection do
          post 'register'
          post 'decommission'
          get  'environment_list'
          get  'environment_id_by_name'
          get  'hostgroup_list'
          get  'hostgroup_id_by_name'
        end
      end
    end
  end

end
