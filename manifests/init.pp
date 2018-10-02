# == Class: goahead
#
# Puppet module to install and configure the goahead client.
#
# === Parameters
#
# [*service_url*]
#   Which URL should the client use.
#
# [*service_url_ca_file*]
#   Local file path that points to the CA file used by the *service_url* endpoint.
#
# === Examples
#
#  class { 'goahead':
#    service_url         => 'https://goahead.domain.tld/',
#    service_url_ca_file => '/etc/ssl/certs/ca-certificates.crt',
#  }
#
# === Authors
#
# Andreas Paul <xorpaul@gmail.com>
#
# === Copyright
#
# Copyright 2018-10-02 16:16 Andreas Paul
#
class goahead (
  String $service_url,
  String $service_url_ca_file,
  String $binary_path = '/usr/local/bin/goahead_client',
  Boolean $add_goahead_user = true,
  Boolean $add_goahead_sudo_rule = false,
  String $goahead_user = 'goahead',
  Boolean $enable_cronjob = false,
  String $config_directory = '/etc/goahead',
  String $config_file = 'client.yml',
){

  if $add_goahead_user {

    user { $goahead_user:
      ensure     => present,
      comment    => 'system user for the goahead client',
      system     => true,
      shell      => '/bin/false',
      managehome => false,
      home       => '/nonexistent',
      before     => [
        File[$config_directory],
        File["${config_directory}/${config_file}"],
        File[$binary_path],
        Cron['goahead_client'],
      ],
    }

    case $add_goahead_sudo_rule {
      true: { $add_goahead_sudo_rule_param_parameter = present }
      false: { $add_goahead_sudo_rule_param_parameter = absent }
      default: { $add_goahead_sudo_rule_param_parameter = absent }
    }

    file { "/etc/sudoers.d/${goahead_user}":
      ensure  => $add_goahead_sudo_rule_param_parameter,
      content => "puppet:///modules/${module_name}/sudo_reboot_rule",
      owner   => 'root',
      group   => 'root',
      mode    => '0440',
    }

  }

  file { $binary_path:
    ensure => present,
    source => "puppet:///modules/${module_name}/goahead_client",
    owner  => $goahead_user,
    group  => 'root',
    mode   => '0744',
  }

  case $enable_cronjob {
    true: { $enable_cronjob_parameter = present }
    false: { $enable_cronjob_parameter = absent }
    default: { $enable_cronjob_parameter = absent }
  }

  cron { 'goahead_client':
    ensure  => $enable_cronjob_parameter,
    command => "test -x ${binary_path} && ${binary_path} &> /var/log/goahead.log",
    user    => $goahead_user,
    hour    => ['10-14'],
    minute  => fqdn_rand('59'),
  }


  file { $config_directory:
    ensure  => 'directory',
    owner   => $goahead_user,
    group   => 'root',
    mode    => '0644',
  } ->
  file { "${config_directory}/${config_file}":
    ensure  => 'present',
    content => epp("${module_name}/config.yml.epp", {'service_url' => $service_url, 'service_url_ca_file' => $service_url_ca_file}),
    owner   => $goahead_user,
    group   => 'root',
    mode    => '0644',
  }

}

# vim: set ts=2 sta shiftwidth=2 softtabstop=2 expandtab foldmethod=syntax :

