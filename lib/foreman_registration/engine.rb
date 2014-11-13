module ForemanRegistration
  class Engine < ::Rails::Engine

    initializer 'foreman_registration.load_default_settings', :before => :load_config_initializers do |app|
      file = '../../../app/models/settings/foreman_registration.rb'
      require_dependency File.expand_path(file, __FILE__) if (Setting.table_exists? rescue(false))
    end

    initializer 'foreman_registration.register_plugin', :after=> :finisher_hook do |app|
      Foreman::Plugin.register :foreman_registration do
        requires_foreman '>= 1.5'

        security_block :foreman_registration do
          permission :register_node, {
            'api/v2/registrations' => [
              :register,
              :reset,
              :decommission,
              :registration_status,
              :reg_environments,
              :reg_hostgroups,
            ]
          }
        end
        role "Registrar", [:register_node]
      end
    end

  end
end
