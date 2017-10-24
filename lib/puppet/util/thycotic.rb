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

    def initialize(host, user, password, organizationCode, domain, ssl_ca_cert_file, logging_enabled)
      @folders = {}
      @templates = {}

      @client = Savon.client do |globals|
        globals.wsdl "https://#{host}/SecretServer/webservices/SSWebService.asmx?wsdl"
        globals.ssl_ca_cert_file ssl_ca_cert_file
        globals.log logging_enabled
        globals.filters [:password, :Token, :token]
        globals.pretty_print_xml true
      end

      if ! defined? @client
        raise RuntimeError, "Failed to connect to #{host}"
      end

      #@token = authenticate({username: user, password: password, domain: domain})
      @token = authenticate({:username => user, :password => password, :domain => domain})
    end

    def authenticate(message)
      #@resp = @client.call(:authenticate, message: message)
      @resp = @client.call(:authenticate, :message => message)
      return nil unless @resp
      @resp = @resp.to_hash
      @result = @resp[:authenticate_response][:authenticate_result][:token]
      return @result
    end

    def request( ws, message)
      #@resp = @client.call(ws, message: message)
      @resp = @client.call(ws, :message => message)
      return nil unless @resp;
      @resp = @resp.to_hash
      return @resp
    end

    def search_secrets(text, secret_type_name = nil, folder = nil)
      valid_template = false
      if !secret_type_name.nil?
        templates = get_secret_templates
        templates.each { |template_id, template_name|
          if template_name == secret_type_name
            valid_template = true
          end
        }
        raise ArgumentError, "Invalid input parameter: secret_type_name" unless valid_template
      end

      r = []
      if folder.nil? or folder.empty?
        #response = request(:search_secrets, { token: @token, searchTerm: text })
        response = request(:search_secrets, { :token => @token, :searchTerm => text })
        @result = response[:search_secrets_response][:search_secrets_result]

        if @result[:secret_summaries]
          if  @result[:secret_summaries][:secret_summary].is_a? Hash
            r << SearchResult.new(@result[:secret_summaries][:secret_summary])
          else
            @result[:secret_summaries][:secret_summary].each {|s|
              r << SearchResult.new(s) if s[:secret_name] ==  text and (secret_type_name.nil? or s[:secret_type_name] == secret_type_name)
            }
          end
        end
      else
        folder_ids = search_folders(folder)
        folder_ids.each { |folder_id|
          #response = request(:search_secrets_by_folder, { token: @token, searchTerm: text, folderId: folder_id, includeSubFolders: true })
          response = request(:search_secrets_by_folder, { :token => @token, :searchTerm => text, :folderId => folder_id, :includeSubFolders => true })
          @result = response[:search_secrets_by_folder_response][:search_secrets_by_folder_result]

          if @result[:secret_summaries]
            if  @result[:secret_summaries][:secret_summary].is_a? Hash
              r << SearchResult.new(@result[:secret_summaries][:secret_summary])
            else
              @result[:secret_summaries][:secret_summary].each { |s|
                r << SearchResult.new(s) if s[:secret_name] == text and (secret_type_name.nil? or s[:secret_type_name] == secret_type_name)
              }
            end
          end
        }
      end

      raise ArgumentError, "No secrets found" if r.length == 0
      raise ArgumentError, "Too many secrets found" if r.length > 1

      return r
    end

    def search_folders(term)
      #response = request(:search_folders, { token: @token, folderName: term })
      response = request(:search_folders, { :token => @token, :folderName => term })
      @result = response[:search_folders_response][:search_folders_result][:folders]
      raise ArgumentError, "No folder found that matches the given search criteria" if @result.nil?

      folder_ids = []
      if @result[:folder].is_a? Hash
        folder_ids << @result[:folder][:id]
      else
        @result[:folder].each { |folder|
          folder_ids << folder[:id]
        }
      end
      return folder_ids
    end

    def get_secret(secret_id)
      if secret_id.class == SecretServer::SearchResult
        secret_id = secret_id.secret_id
      end
      #response = request(:get_secret, { token: @token, secret_id: secret_id })
      response = request(:get_secret, { :token => @token, :secret_id => secret_id })
      @result = response[:get_secret_response][:get_secret_result]
      Secret.new(@result[:secret])
    end

    def get_secret_templates
      #response = request(:get_secret_templates, { token: @token})
      response = request(:get_secret_templates, { :token => @token})
      @result = response[:get_secret_templates_response][:get_secret_templates_result]
      templates = {}
      if @result[:secret_templates]
        @result[:secret_templates][:secret_template].each { |template|
          templates[template[:id]] = template[:name]
        }
      end
      return templates
    end
  end
end
