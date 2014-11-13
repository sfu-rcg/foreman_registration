require "foreman_registration/engine"

module ForemanRegistration

  # Send a message to the Rails log
  def log(msg)
    Rails.logger.error "[RegistrationsController] #{msg}"
  end

  class ForeignApiClient

    require 'faraday'

    def initialize(server, user=nil, password=nil)
      @server     = server
      @connection = connect(server, user, password)
    end

    # Connect to The Foreman
    def connect(server, user=nil, password=nil)
      conn = Faraday.new(:url => server, :ssl => {:verify => false}) do |faraday|
        faraday.request  :url_encoded             # form-encode POST params
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end
      conn.basic_auth user, password if user or password
      conn
    end

    def query(op, url, body=nil)
      @connection.send(op) do |req|
        req.url url
        req.headers['Accept']       = 'application/json'
        req.headers['Content-Type'] = 'application/json'
        req.body = body.to_json if body
      end
    end

  end

end
