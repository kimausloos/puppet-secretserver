require 'puppet/util/thycotic'
require 'puppet'

module Puppet::Parser::Functions
  include Puppet::Util::Thycotic

  newfunction(:ss_get_password, :type => :rvalue) do |args|
    configfile = "#{Puppet.settings[:confdir]}/secretserver.yaml"
    raise(Puppet::ParseError, "SecretServer config file #{configfile} not readable") unless File.exist?(configfile)

    config = YAML.load_file(configfile)
    ss_hostname = config[:ss_hostname]
    ss_username = config[:ss_username]
    ss_password = config[:ss_password]
    ss_ssl_ca_cert_file = config[:ss_ssl_ca_cert_file]
    logging_enabled = config[:logging_enabled]

    search_text, template_name, folder = args
    template_name ||= nil
    folder ||= nil

    Puppet.debug("ss_hostname: #{ss_hostname}")
    Puppet.debug("ss_username: #{ss_username}")
    Puppet.debug("ss_password: #{ss_password}")
    Puppet.debug("ss_ssl_ca_cert_file: #{ss_ssl_ca_cert_file}")
    Puppet.debug("logging_enabled: #{logging_enabled}")

    password = ''

    begin
      ss = SecretServer.new(ss_hostname, ss_username, ss_password, '', '', ss_ssl_ca_cert_file, logging_enabled)
      s = ss.search_secrets(search_text, template_name, folder)
      secret = ss.get_secret(s[0].secret_id)
      password = secret.password
    rescue ArgumentError => ex
      raise(Puppet::Error, ex)
    end

    Puppet.debug("Password for #{search_text} is #{password}") if logging_enabled

    return password
  end
end
