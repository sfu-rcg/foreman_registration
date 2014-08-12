module Api
  module V2
    class RegistrationsController < V2::BaseController
      unloadable

      require 'faraday'

      def register
        host_attributes = validate_params params
        host = Host.find_by_certname params[:certname]
        op = if host
          revoke_cert params[:certname]
          :update_attributes
        else
          :new
        end
        if host.send(op, host_attributes)
          render :text => "Success!", :status => 200
          host.save
        else
          render :text => "Registration Failed!", :status => 200
        end
      end

      private

      def validate_params(params)
        render :text => "You must include a certname key", :status => 400 if params[:certname].nil?
        params.select { |k,v| [:name, :certname, :environment_id, :hostgroup_id, :comment].include?(k) }
      end

      def revoke_cert(certname)
        conn = Faraday.new(:url => PUPPET_CA, :ssl => {:verify => false}) do |faraday|
          faraday.request  :url_encoded
          faraday.adapter  Faraday.default_adapter
        end

        response = conn.delete do |request|
          request.url [CA_PATH, certname].join('/')
          request.body = {}
        end

        case response.status
        when 200
          true
        when 404
          true
        else
          raise "Error: response was \'#{response.env.response_headers['status']}\' while trying to revoke `#{certname}`"
        end
      end

    end
  end
end
