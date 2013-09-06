require 'savon'
require 'base64'
require 'excon'

module Puppet::Util::Thycotic
  class SecretServer
    attr_reader :error, :result, :templates, :folders

    class Secret
      attr_reader :secret

       def initialize(s)
         @secret = s
       end

       def update(what)
         @secret[:items][:secret_item].each do |f|
           if  what[f[:field_name]]
             f[:value] =  what[f[:field_name]]
              what.delete(f[:field_name])
           end
         end
         raise ArgumentError, "field ''#{what.keys.join(',')}' not found in secret" if what.size > 0

       end
       @secret

       def password
         password = nil
         @secret[:items][:secret_item].each do |f|
         if f[:is_password]
            password = f[:value]
          end
        end
        return password
      end
    end

    class SearchResult

      def initialize(results)
          @search_result = results
      end

      def secret_id
         @search_result[:secret_id]
      end
      def secret_name
         @search_result[:secret_name]
      end
      def secret_type_name
         @search_result[:secret_type_name]
      end

    end

    def initialize(host, user, password, organizationCode, domain, ssl_ca_cert_file)
      @folders = {}
      @templates = {}

      (pw, rad) =  password.split(':')

      @client = Savon.client do |globals|
        globals.wsdl "https://#{host}/webservices/SSWebService.asmx?wsdl"
        globals.ssl_ca_cert_file ssl_ca_cert_file
      end

      if ! defined? @client
        raise RuntimeError, "Failed to connect to #{host}"
      end

      @token = authenticate({username: user, password: pw, domain: domain})
    end

    def authenticate(message)
      @resp = @client.call(:authenticate, message: message)
      return nil unless @resp
      @resp = @resp.to_hash
      @result = @resp[:authenticate_response][:authenticate_result][:token]
      return @result
    end

    def request( ws, message)
      @resp = @client.call(ws, message: message)
      return nil unless @resp;
      @resp = @resp.to_hash
      return @resp
    end

    def search_secrets(text)
      response = request(:search_secrets, { token: @token, searchTerm: text })
      @result = response[:search_secrets_response][:search_secrets_result]

      r = []
      if @result[:secret_summaries]
        if  @result[:secret_summaries][:secret_summary].is_a? Hash
          x = {}
          @result[:secret_summaries][:secret_summary].each {|y|
            x[y[0]] = y[1]
          }
          r << SearchResult.new(x)
        else
          @result[:secret_summaries][:secret_summary].each {|s|
            r << SearchResult.new(s)
          }
        end
      end
      return r
    end

    def get_secret(secret_id)
      if secret_id.class == SecretServer::SearchResult
        secret_id = secret_id.secret_id
      end
      response = request(:get_secret, { token: @token, secret_id: secret_id })
      @result = response[:get_secret_response][:get_secret_result]
      Secret.new(@result[:secret])
    end

  end
end
