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

      # Get a list of environment names
      def environment_list
        list_resources_by_attribute(Environment, :name)
      end

      # Lookup an environment :id by name
      def environment_id_by_name
        attribute_to_id(Environment, :name)
      end

      # Get a list of environment names
      def hostgroup_list
        list_resources_by_attribute(Hostgroup, :title)
      end

      # Lookup hostgroup :id by name
      def hostgroup_id_by_name
        attribute_to_id(Hostgroup, :title)
      end

      ###############################################################
      # Registration Logic:
      ###############################################################
      #
      #### Initial Deployment
      #
      # Our deployment process implies pre-registration. In order for another
      # admin to determine what config a machine receives, the node record
      # must be created in Foreman prior to first Puppet run.
      #
      # If this is completed properly, when the Puppet agent runs for the
      # first time, the registration will associate itself with the
      # designated record, according to :name.
      #
      # If the :name cannot be found, a new record will be created using
      # default specifications.
      #
      ##### Re-deployment
      #
      # If the machine already has a certname, it is not a new deployment, but
      # re-deployment. Therefore, the only operation required is to revoke the
      # existing certificate.
      #
      # So...
      #
      # 1. Look-up by certname: if it exists, just revoke the cert so that
      # it can be re-generated and auto-signed during the first Puppet run.
      #
      # 2. Look-up by FQDN (name): If it's found, update the existing
      # record's :certname attribute to match the one generated on the
      # client, then revoke the existing cert.
      #
      # 3. Contingency: if there is no existing record to be found, create
      # the record with the required parameters.
      #
      def register
        required  = ['name', 'certname', 'environment_id', 'hostgroup_id']
        validated = validate_params(params, required)
        @host     = Host::Managed.find_by_certname validated['certname']
        if @host # HAS A CERTNAME
          revoke_cert validated['certname']
        else
          @host = Host::Managed.find_by_name validated['name']
          if @host # HAS A NODE RECORD
            update validated
            revoke_cert validated['certname']
          else
            create validated
          end
        end
        respond_success
        log("Node: #{validated['name']} | #{validated['certname']} registered successfully")
      end

      # Decomission a node
      def decommission
        required  = ['name']
        validated = validate_params(params, required)
        @host = Host::Managed.find_by_name validated['name']
        destroy if @host
        respond_success
      end

      private

        # Shared method for list methods
        def list_resources_by_attribute(object, attribute)
          resources = object.pluck(attribute).sort
          render :json => resources.to_json, :status => 200
        end

        # Shared method for :name to :id lookups
        def attribute_to_id(object, attribute)
          name   = params[:name]
          method = 'find_by_' + attribute.to_s
          result = object.send(method, name)
          map    = { :id => result.nil? ? result : result.id }
          render :json => map.to_json, :status => 200
        end

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
        def respond_success
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
        def validate_params(params, required)
          filtered = params.select { |k,v| required.include?(k) }
          unless filtered.keys.sort == required.sort
            raise ActiveModel::MissingAttributeError.new "You did not specify a required parameter: #{filtered}"
          end
          filtered
        end

        # Create a new node record
        def create(attrs)
          begin
            @host = Host::Managed.new(attrs)
            @host.save
          rescue => err
            log "Exception #{err.class}: #{err.message}"
            raise Api::V2::RegistrationsControllerError.new "Could not create record. [#{err.message}]"
          end
        end

        # Update reg operation
        def update(attrs)
          begin
            @host.certname = attrs['certname']
            @host.save
          rescue => err
            log "Exception #{err.class}: #{err.message}"
            raise Api::V2::RegistrationsControllerError.new "Could not update record. [#{err.message}]"
          end
        end

        # Destroy the node record and cert
        def destroy
          begin
            revoke_cert @host.certname if @host.certname
            @host.destroy
          rescue => err
            log "Exception #{err.class}: #{err.message}"
            raise Api::V2::RegistrationsControllerError.new "Could not destroy record. [#{err.message}]"
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
