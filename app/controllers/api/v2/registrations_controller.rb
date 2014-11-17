module Api
  module V2

    class RegistrationsControllerError < StandardError
    end

    class RegistrationsController < V2::BaseController

      require 'foreman_registration'

      include ForemanRegistration

      unloadable

      FOREMAN_SMART_PROXY_CA_FEATURE = 'Puppet CA'

      # Skip auth callbacks and other security features for status lookups
      skip_before_filter :require_login,        :only   => :registration_status
      skip_before_filter :authorize,            :only   => :registration_status
      skip_before_filter :set_taxonomy,         :only   => :registration_status
      skip_before_filter :session_expiry,       :only   => :registration_status
      skip_before_filter :update_activity_time, :only   => :registration_status

      before_filter :check_ip,    :except => :registration_status

      before_filter :set_user
      before_filter :check_user,  :only   => [:hostgroups, :register, :reset, :decommission]
      before_filter :find_node,   :only   => [:reset, :decommission]
      before_filter :check_node,  :only   => [:reset, :decommission]
      before_filter :extend_host, :only   => [:reset, :decommission]
      before_filter :check_auth,  :only   => [:reset, :decommission]

      rescue_from Api::V2::RegistrationsControllerError,
        with: :respond_internal_error
      rescue_from ActiveModel::MissingAttributeError,
        with: :respond_internal_error

      # ENVIRONMENTS
      def environments
        render_data_as_json Environment.all
      end

      # HOSTGROUPS
      def hostgroups
        required  = ['login', 'environment_id']
        validated = validate_params(required)
        env  = Environment.find validated['environment_id']
        data = if env
          Hostgroup.all.select do |g|
            g.environment.id == env.id and g.authorized?(:edit_hostgroups)
          end
        else
          Hostgroup.authorized(:edit_hostgroups)
        end
        render_data_as_json data
      end

      # REGISTER
      # - pre-creates node or updates an existing one
      # - requires explicit call to #extend_host and #check_mac
      def register
        required  = ['name', 'environment_id', 'hostgroup_id', 'mac', 'certname']
        validated = validate_params(required)
        @host     = Host::Managed.new validated
        msg, code = ["Registered node: #{@host.name} for user: #{@user.login}", 200]
        begin
          extend_host
          check_mac
          @host.save!
        rescue ActiveRecord::RecordInvalid => e
          msg, code = [e.message, 403]
        end
        respond_and_log msg, code
      end

      # RESET
      def reset
        reset_or_decommission __method__
      end

      # DECOMMISSION
      def decommission
        reset_or_decommission __method__
      end

      # REGISTRATION STATUS
      def registration_status
        required  = ['certname']
        validated = validate_params(required)
        keys      = [:name, :last_report, :has_certificate?]
        @host     = Host::Managed.find_by_certname validated['certname']
        data = if @host
          extend_host
          keys.inject({}) { |memo, m| memo[m] = @host.send m; memo }
        else
          Hash[keys.map {|x| [x, nil]}]
        end
        render_data_as_json data
      end

      private

      # Routine that resets or decommissions the node
      # - this method is called by both operations
      # - it does one or both depending on which method called it
      def reset_or_decommission(method_name)
        required  = ['name', 'login']
        validated = validate_params(required)
        @host.revoke
        @host.destroy if method_name == :decommission
        respond_and_log "Success: #{method_name} #{validated['name']}, #{validated['login']}", 200
      end

      def find_node
        @host = Host::Managed.find_by_name params[:name]
        extend_host
      end

      def set_user
        @user = User.current = User.find_by_login params[:login]
      end

      def check_user
        respond_and_log "Unauthorized", 403 if @user.nil?
      end

      def check_mac
        unless @host.mac_is_unique?
          raise ActiveRecord::RecordInvalid.new @host
        end
      end

      def check_node
        respond_and_log "Resource not found", 404 if @host.nil?
      end

      def check_auth
        respond_and_log "Unauthorized", 403 unless @host.authorized? :edit_hosts
      end

      def check_ip
        client_ip   = request.remote_ip
        allowed_ips = Setting.find_by_name(:foreman_registration_allowed_hosts).value
        unless allowed_ips.member? client_ip
          respond_and_log "Unauthorized [#{client_ip}]", 403
        end
      end

      # Render the results of a query as JSON
      def render_data_as_json(data, status=200)
        render :json => data.to_json, :status => status
      end

      # Generic HTTP response method with Rails logging
      def respond_and_log(msg, code=200, result=nil)
        log(msg)
        render_data_as_json({ :result => result, :message => msg }, code)
      end

      # Standard error response 500
      def respond_internal_error(err)
        respond_and_log(err.message, 500, false)
      end

      # Ensure only valid params are accepted and required params are present
      def validate_params(required)
        filtered = params.select do |k,v|
          unless v.is_a? Fixnum or v.is_a? Float
            next if v.nil? or v.empty?
          end
          required.include?(k)
        end
        unless filtered.keys.sort == required.sort
          raise ActiveModel::MissingAttributeError.new "Required parameter missing: #{filtered}"
        end
        filtered['comment'] = params['comment'] if params['comment']
        filtered
      end

      # Insert custom methods into our @host instance
      def extend_host
        class << @host

          require 'uri'
          require 'foreman_registration'

          include ForemanRegistration

          # Get a list of Puppet CAs configured in Foreman
          def get_ca_smart_proxy
            SmartProxy.joins(:features).where(:features => {
              :name => FOREMAN_SMART_PROXY_CA_FEATURE }).first
          end

          def get_ca_server
            if proxy = get_ca_smart_proxy
              URI(proxy.url)
            else
              raise Api::V2::RegistrationsControllerError.new
                "Puppet CA Smart Proxy not configured."
            end
          end

          def ca_server_certificate_operation(op, resource)
            if certname.nil? or certname.empty?
              raise Api::V2::RegistrationsControllerError.new "Invalid certname: `#{certname}'"
            end
            ForeignApiClient.new(get_ca_server).query op, resource
          end

          def has_certificate?
            resource = '/puppet/ca'
            response = ca_server_certificate_operation(:get, resource)
            JSON.parse(response.body)[certname].nil? ? false : true
          end

          # Revoke the client's certificate from the CA Smart Proxy
          # - returns Faraday::Response obj
          def revoke
            resource  = ['/puppet/ca', certname].join('/')
            response = ca_server_certificate_operation(:delete, resource)
            case response.status
            when 200, 404
              log "Puppet CA Response: #{response.status} #{response.body}"
              true
            else
              raise Api::V2::RegistrationsControllerError.new
                "#{ca_server}: returned #{response.status}, #{response.body}"
            end
          end

          # Is the mac attribute unique?
          def mac_is_unique?
            if @duplicate_mac = Host::Managed.find_by_mac(mac)
              self.errors.instance_variable_set(:@messages,
                {:mac => ["not unique, [#{@duplicate_mac.name}]"]})
            end
            @duplicate_mac.nil?
          end

        end
      end

    end
  end
end
