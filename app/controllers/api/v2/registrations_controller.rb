module Api
  module V2

    class RegistrationsControllerError < StandardError
    end

    class RegistrationsController < V2::BaseController

      require 'faraday'

      unloadable

      before_filter :check_smart_proxy_ca
      rescue_from ActiveModel::MissingAttributeError,    with: :register_error
      rescue_from Api::V2::RegistrationsControllerError, with: :register_error

      FOREMAN_SMART_PROXY_CA_FEATURE = 'Puppet CA'

      # A registration implies node creation, unless it already exists, in
      # which case it simply means we are redeploying so, revoke the cert.
      def register
        validated = validate_params params
        host      = Host::Managed.find_by_certname validated['certname']
        if host
          revoke_cert validated['certname'] if host['certname']
        else
          create validated
        end
        register_success
        log("Node: #{validated['name']} | #{validated['certname']} registered successfully")
      end

      private

        # Seatbelt: if you do not have a 'Puppet CA' Smart Proxy,
        # this method will fail ALL calls to #register and return 500
        # Called by the `before_filter`.
        def check_smart_proxy_ca
          @ca_api_path = '/puppet/ca'
          @ca_proxies  = SmartProxy.joins(:features).where(:features =>
            { :name => FOREMAN_SMART_PROXY_CA_FEATURE })
          @ca_proxy    = @ca_proxies.first
          unless @ca_proxy
            raise Api::V2::RegistrationsControllerError.new "You must configure a `Puppet CA` Smart Proxy to use the Registration controller!"
          end
          log("More than one `Puppet CA` defined!") if @ca_proxies.length > 1
        end

        # Send a message to the Rails log
        def log(msg)
          Rails.logger.error "[RegistrationsController] #{msg}"
        end

        # Standard success response 200
        def register_success
          body = { :result  => true, :message => 'Success!' }
          render :json => body.to_json, :status => 200
        end

        # Standard error response 500
        def register_error(err)
          body = { :result  => false, :message => err.message }
          log "Exception #{err.class}: #{err.message}"
          render :json => body.to_json, :status => 500
        end

        # Ensure only valid params are accepted and that required params
        # are present
        def validate_params(params)
          required = ['name', 'certname', 'environment_id', 'hostgroup_id']
          filtered = params.select { |k,v| required.include?(k) }
          unless filtered.keys.sort == required.sort
            raise ActiveModel::MissingAttributeError.new "You did not specify a required parameter: #{filtered}"
          end
          filtered
        end

        # Create a new node record
        def create(attrs)
          begin
            host = Host::Managed.new(attrs)
            host.save
          rescue => err
            log "Exception #{err.class}: #{err.message}"
            raise Api::V2::RegistrationsControllerError.new "Could not create record. [#{err.message}]"
          end
        end

        # Revoke a client certificate from the CA Smart Proxy
        def revoke_cert(certname)
          if @ca_proxy
            conn = Faraday.new(:url => @ca_proxy.url, :ssl => {:verify => false}) do |faraday|
              faraday.request  :url_encoded
              faraday.adapter  Faraday.default_adapter
            end

            response = conn.delete do |request|
              request.url [@ca_api_path, certname].join('/')
              request.body = {}
            end

            case response.status
            when 200
              true
            when 404
              true
            else
              status = response.env.response_headers['status']
              raise Api::V2::RegistrationsControllerError.new "Error: response was \'#{status}\' while trying to revoke `#{certname}`"
            end
          else
            raise Api::V2::RegistrationsControllerError.new "You must configure a `Puppet CA` Smart Proxy to use the Registration controller!"
          end
        end

    end
  end
end
