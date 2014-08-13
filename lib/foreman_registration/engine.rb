module ForemanRegistration
  class Engine < ::Rails::Engine

    initializer 'foreman_registration.register_plugin', :after=> :finisher_hook do |app|
      Foreman::Plugin.register :foreman_registration do
        requires_foreman '>= 1.5'

        security_block :foreman_registration do
          permission :register_node, {
            'api/v2/registrations' => [
              :register,
              :environment_list,
              :environment_id_by_name,
              :hostgroup_list,
              :hostgroup_id_by_name,
            ]
          }
        end
        role "Registrar", [:register_node]
      end
    end

  end
end
