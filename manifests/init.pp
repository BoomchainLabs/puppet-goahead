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
  Boolean $add_init_6_restart_hook = false,
  String $goahead_user = 'goahead',
  Boolean $enable_cronjob = false,
  String $config_directory = '/etc/goahead',
  String $config_file = 'client.yml',
  String $log_file = '/var/log/goahead.log',
  String $restart_condition_script = "${config_directory}/check_restart_condition.sh",
  Integer $restart_condition_script_exit_code_for_reboot = 0,
  String $os_restart_hooks_dir = "${config_directory}/restart_hooks.d",
  Boolean $purge_os_restart_hooks_dir = true,
  Integer $cron_minute_offset = 1,
  String $cronjob_hour = '9-15',
  String $cronjob_weekday = '1-5',
) {
  if $add_goahead_user {
    user { $goahead_user:
      ensure     => present,
      comment    => 'system user for the goahead client',
      system     => true,
      shell      => '/bin/false',
      managehome => false,
      home       => $config_directory,
      before     => [
        File[$config_directory],
        File["${config_directory}/${config_file}"],
        File[$binary_path],
        File[$binary_path],
        File[$log_file],
        Cron['goahead_client'],
        Cron['goahead_client_reboot'],
      ],
    }

    case $add_goahead_sudo_rule {
      true: { $add_goahead_sudo_rule_param_parameter = present }
      false: { $add_goahead_sudo_rule_param_parameter = absent }
      default: { $add_goahead_sudo_rule_param_parameter = absent }
    }

    file { "/etc/sudoers.d/${goahead_user}":
      ensure  => $add_goahead_sudo_rule_param_parameter,
      content => epp("${module_name}/sudo_reboot_rule.epp", { 'goahead_user' => $goahead_user }),
      owner   => 'root',
      group   => 'root',
      mode    => '0440',
    }

    if $add_init_6_restart_hook {
      file { "${os_restart_hooks_dir}/999_sudo_init_6.sh":
        ensure  => file,
        content => "puppet:///modules/${module_name}/999_sudo_init_6.sh",
        owner   => 'root',
        group   => 'root',
        mode    => '0440',
      }
    }
  }

  file { $binary_path:
    ensure => file,
    source => "puppet:///modules/${module_name}/goahead_client",
    owner  => $goahead_user,
    group  => 'root',
    mode   => '0544',
  }

  case $enable_cronjob {
    true: { $enable_cronjob_parameter = present }
    false: { $enable_cronjob_parameter = absent }
    default: { $enable_cronjob_parameter = absent }
  }

  $fqdnrand5 = fqdn_rand('5')
  file { $log_file:
    ensure => 'file',
    owner  => $goahead_user,
    group  => 'root',
    mode   => '0640',
  }
  -> file { '/etc/cron.d/goahead_client':
    ensure  => $enable_cronjob_parameter,
    content => "*/${$fqdnrand5 + $cron_minute_offset} ${cronjob_hour} * * ${cronjob_weekday} goahead sleep ${fqdn_rand('50')} && ${binary_path} --config ${config_directory}/${config_file} &>> ${log_file}\n@reboot goahead sleep ${fqdn_rand('50')} && ${binary_path} --config ${config_directory}/${config_file} &>> ${log_file}\n",
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }
  file { $config_directory:
    ensure => 'directory',
    owner  => $goahead_user,
    group  => 'root',
    mode   => '0644',
  }
  -> file { "${config_directory}/${config_file}":
    ensure  => 'file',
    content => epp("${module_name}/config.yml.epp", { 'service_url' => $service_url, 'service_url_ca_file' => $service_url_ca_file, 'restart_condition_script_exit_code_for_reboot' => $restart_condition_script_exit_code_for_reboot, 'restart_condition_script' => $restart_condition_script, 'os_restart_hooks_dir' => $os_restart_hooks_dir }),
    owner   => $goahead_user,
    group   => 'root',
    mode    => '0644',
  }
  -> file { $os_restart_hooks_dir:
    ensure  => 'directory',
    owner   => $goahead_user,
    group   => 'root',
    mode    => '0644',
    backup  => false,
    purge   => $purge_os_restart_hooks_dir,
    recurse => $purge_os_restart_hooks_dir,
  }
}

# vim: set ts=2 sta shiftwidth=2 softtabstop=2 expandtab foldmethod=syntax :
