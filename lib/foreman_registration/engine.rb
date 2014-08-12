module ForemanRegistration
  class Engine < ::Rails::Engine

    # config.to_prepare do
    #   if SETTINGS[:version].to_s.to_f >= 1.2
    #     # Foreman 1.2
    #     Host::Managed.send :include, Host::HostExtensions
    #   else
    #     # Foreman < 1.2
    #     Host.send :include, Host::HostExtensions
    #   end
    # end

    initializer 'foreman_registration.register_plugin', :after=> :finisher_hook do |app|
      Foreman::Plugin.register :foreman_registration do
        requires_foreman '>= 1.5'

        security_block :foreman_registration do
          permission :register_node, { 'api/v2/register' => [:register] }
        end

        role "Registrar", [:register_node]
      end
    end

  end
end
