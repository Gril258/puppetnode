class puppetnode::agent(
  $server,
  $runinterval = '14400',
  $puppet_package = undef,
  $config_path = undef,
  $ssl_dir = '/var/lib/puppet/ssl',
) {

  case $::operatingsystem {
    'Debian': {
      case $::operatingsystemmajrelease {
        '9': {
          $packages = ['puppet-common', 'puppet']
          $config_file_path =  '/etc/puppet/puppet.conf'
        }
        '11': {
          $packages = ['puppet']
          $config_file_path =  '/etc/puppet/puppet.conf'
        }
        default: {
          $packages = ['puppet-common', 'puppet']
          $config_file_path =  '/etc/puppet/puppet.conf'
        }
      }
    }
    'Centos':{
      $packages = ['puppet-agent']
      $config_file_path =  '/etc/puppetlabs/puppet/puppet.conf'
    }
    default: {
      $packages = ['puppet-agent']
    }
  }

  $puppet_confpath = pick($config_path, $config_file_path)
  $puppet_package_toinstall = pick($puppet_package,  $packages)
  package { $puppet_package_toinstall:
    ensure => 'latest'
  }

  file { '/etc/puppet/puppet.conf':
    ensure  => 'file',
    content => template("puppetnode/agent.erb"),
    require => Package[$puppet_package_toinstall],
    notify  => Service['puppet']
  }

  exec {
    'puppetnode-systemctl-daemon-reload':
      command     => 'systemctl daemon-reload',
      refreshonly => true,
  }

  file { '/lib/systemd/system/puppet.service':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('puppetnode/systemd.service.erb'),
    notify  => Exec['puppetnode-systemctl-daemon-reload'],
    require => Package[$puppet_package_toinstall],
  }


  service { 'puppet':
    ensure  => 'running',
    enable  => true,
    require => Package[$puppet_package_toinstall]
  }
  
  # it look like we dont need this
  #apt::key { 'puppetlabs':
  #  id      => '7F438280EF8D349F',
  #  server  => 'pgp.mit.edu',
  #}
}
