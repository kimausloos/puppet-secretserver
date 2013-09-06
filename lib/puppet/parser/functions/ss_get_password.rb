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
    search_text = args[0]

    Puppet.debug("ss_hostname: #{ss_hostname}")
    Puppet.debug("ss_username: #{ss_username}")
    Puppet.debug("ss_password: #{ss_password}")

    password = ''

    ss = SecretServer.new(ss_hostname, ss_username, ss_password, '', '')
    s = ss.search_secrets(search_text)
    s.each { |result|
      secret = ss.get_secret(result.secret_id)
      password = secret.password
    }

    Puppet.info("Password for #{search_text} is #{password}")
  end
end
