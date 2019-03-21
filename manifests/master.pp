class puppetnode::master(
  $server_jvm_max_heap_size = '4096m',
  $server_jvm_min_heap_size = '2048m'
) {

  case $facts['operatingsystemmajrelease'] {
    '8': {
      $puppet_package_version      = '1.10.1-1jessie'
      $server_version              = '2.7.2-1puppetlabs1'
      $server_puppetserver_version = '2.7.2'
      $puppet_collections          = 'jessie'
      $release_package             = "puppetlabs-release-pc1-${puppet_collections}.deb"
    }
    '9': {
      $puppet_package_version      = '6.2.0-1stretch'
      $server_version              = '6.2.0-1stretch'
      $server_puppetserver_version = '6.2.0'
      $puppet_collections          = 'stretch'
      $release_package             = "puppet-release-stretch.deb"
    }
    default: {
      # default - can be anything
      fail("unsupported os release")
    }
  }

  $puppet_repo = "https://apt.puppetlabs.com/"

  #install release package

  exec { 'install-collection':
    command => "wget ${puppet_repo}${release_package};dpkg -i ${release_package}",
    user    => 'root',
    path    => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
    creates => '/tmp/${release_package}',
    cwd     => '/tmp/',
    require => Package['wget', 'ca-certificates']
  }

# file { '/var/lib/puppet':
#  ensure => link,
#  target => '/opt/puppetlabs/puppet',
#  before => Class['::puppet']
#}

  file { '/etc/puppetserver':
    ensure => link,
    target => '/etc/puppetlabs/puppetserver',
    before => Class['::puppet']
  }

  file { '/etc/puppetdb':
    ensure => link,
    target => '/etc/puppetlabs/puppetdb',
    before => Class['::puppet']
  }

#file { '/etc/puppet':
#  ensure => link,
#  target => '/etc/puppetlabs/puppet',
#  before => Class['::puppet']
#}

  class { '::puppet':
    server                      => true,
    server_git_repo             => false,
    server_foreman              => false,
    server_external_nodes       => '',
    server_puppetdb_host        => $::fqdn,
    server_reports              => 'puppetdb',
    server_storeconfigs_backend => 'puppetdb',
    server_implementation       => 'puppetserver',
    version                     => $puppet_package_version,
    server_version              => $server_version,
    server_puppetserver_version => $server_puppetserver_version,
    server_jvm_min_heap_size    => $server_jvm_min_heap_size,
    server_jvm_max_heap_size    => $server_jvm_max_heap_size,
    server_jvm_extra_args       => '-Dfile.encoding=UTF-8',
  }

  file { '/etc/puppetlabs/puppet/fileserver.conf':
    ensure  => 'file',
    content => template("puppetnode/fileserver.conf.erb"),
    require => Class['::puppet']
  }

# class { 'postgresql::globals':
#   version         => '9.6',
#   postgis_version => '2.1',
# }

  class { 'puppetdb':
    database_validate => false,
    require           => Class['::puppet', 'postgresql::globals'],
  }

  file { '/etc/puppet/files':
    ensure  => 'directory',
    owner   => 'puppet',
    group   => 'puppet',
    require => Class['::puppet']
  }

  file { '/etc/puppet/files/production':
    ensure  => link,
    target  => '../environments/production/files',
    require => Class['::puppet']
  }


  package { ['ruby', 'ruby-dev', 'build-essential']:
    ensure => 'latest'
  }

  exec {'install librarian-puppet':
    command => '/usr/bin/gem install librarian-puppet',
    creates => '/usr/local/bin/librarian-puppet',
    require => Package['ruby-dev'],
  }

  cron { 'remove reports older than 14 days':
    command  => '/usr/bin/find /var/lib/puppet/reports -type f -name "*.yaml" -mtime -14 -delete',
    user     => 'root',
    month    => '*',
    monthday => '*',
    hour     => '*/6',
    minute   => '*',
    require  => Class['::puppet']
  }

  class { '::postfix::server':
    extra_main_parameters => {
      'inet_protocols' => 'ipv4'
    }
  }
}