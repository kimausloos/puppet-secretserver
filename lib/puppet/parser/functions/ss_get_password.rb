require 'puppet/util/thycotic'
require 'puppet'

module Puppet::Parser::Functions
  include Puppet::Util::Thycotic

  newfunction(:ss_get_password, :type => :rvalue) do |args|
    configfile = File.join([File.dirname(Puppet.settings[:config]), "secretserver.yaml"])
    raise(Puppet::ParseError, "SecretServer config file #{configfile} not readable") unless File.exist?(configfile)

    config = YAML.load_file(configfile)
    ss_hostname = config[:ss_hostname]
    ss_username = config[:ss_username]
    ss_password = config[:ss_password]
    ss_ssl_ca_cert_file = config[:ss_ssl_ca_cert_file]
    ss_folder_context = config[:ss_folder_context] || ''

    search_text, template_name, folder = args
    template_name ||= nil
    folder ||= ''

    Puppet.debug("ss_hostname: #{ss_hostname}")
    Puppet.debug("ss_username: #{ss_username}")
    Puppet.debug("ss_password: #{ss_password}")
    Puppet.debug("ss_ssl_ca_cert_file: #{ss_ssl_ca_cert_file}")
    Puppet.debug("ss_folder_context: #{ss_folder_context}")

    password = ''

    begin
      ss = SecretServer.new(ss_hostname, ss_username, ss_password, '', '', ss_ssl_ca_cert_file)
      folder = ss_folder_context + "\\" + folder unless ss_folder_context.empty?
      if template_name.nil? and folder.empty?
        s = ss.search_secrets(search_text)
      else
        s = ss.search_secrets(search_text, template_name, folder)
      end
      s.each { |result|
        secret = ss.get_secret(result.secret_id)
        password = secret.password
      }
    rescue ArgumentError
      raise(Puppet::ParseError, "Invalid input parameter")
    end

    Puppet.info("Password for #{search_text} is #{password}")
    return password
  end
end
