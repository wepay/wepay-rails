require 'active_record'
require 'helpers/model_helpers'
require 'helpers/controller_helpers'
require 'exceptions'
module WepayRails
  module Payments
    class Gateway
      include HTTParty

      base_uri @base_uri

      attr_accessor :wepay_access_token, :wepay_auth_code, :scope

      def initialize(*args)
        yml = Rails.root.join('config', 'wepay.yml').to_s
        @config = YAML.load_file(yml)[Rails.env].symbolize_keys
        @scope = @config.delete(:scope)
        @base_uri = Rails.env.production? ? "https://api.wepay.com" : "https://stage.wepay.com"
      end

      def access_token(auth_code)
        @wepay_auth_code = auth_code
        response = self.class.get("#{@base_uri}/v2/oauth2/token", :query => @config.merge(:code => auth_code))
        json = JSON.parse(response.body)

        if json.has_key?("error")
          if json.has_key?("error_description")
            raise WepayRails::Exceptions::ExpiredTokenError.new("You will need to get a new authorization code") if json["error_description"] == "the code has expired"
            raise WepayRails::Exceptions::AccessTokenError.new(json["error_description"])
          end
        end

        raise WepayRails::Exceptions::AccessTokenError.new("A problem occurred trying to get the access token: #{json.inspect}") unless json.has_key?("access_token")

        @wepay_access_token = json["access_token"]
      end

      # Get the auth code for the customer
      # arguments are the redirect_uri and an array of permissions that your application needs
      # ex. ['manage_accounts','collect_payments','view_balance','view_user']
      def auth_code_url(permissions)
        params = @config.merge(:scope => permissions.join(','))

        query = params.map do |k, v|
          "#{k.to_s}=#{v}"
        end.join('&')

        "#{@base_uri}/v2/oauth2/authorize?#{query}"
      end

      def token_url
        query = @config.map do |k, v|
          "#{k.to_s}=#{v}"
        end.join('&')

        "#{@base_uri}/v2/oauth2/authorize?#{query}"
      end

      def wepay_auth_header
        {'Authorization' => "Bearer: #{@wepay_access_token}"}
      end

      def wepay_user
        response = self.class.get("#{@base_uri}/v2/user", {:headers => wepay_auth_header})
        JSON.parse(response.body)
      end
    end

    include WepayRails::Exceptions
    include WepayRails::Helpers::ControllerHelpers
  end


  def self.included(base)
    base.extend WepayRails::Helpers::ModelHelpers
  end
end
ActiveRecord::Base.send(:include, WepayRails)