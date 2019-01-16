class puppetnode::master(
  $server_jvm_max_heap_size = '4096m',
  $server_jvm_min_heap_size = '2048m'
  ) {

  if $facts['operatingsystemmajrelease'] == '8' {
    $puppet_package_version = '1.10.1-1jessie',
    $puppet_collections     = 'jessie'
  }
  elsif $facts['operatingsystemmajrelease'] == '9' {
    $puppet_package_version = 'puppet5-release-stretch',
    $puppet_collections     = 'stretch'
  }
  else {
    # default - can be anything
    $puppet_package_version = '1.10.1-1jessie',
    $puppet_collections     = 'jessie'
  }

  #install collection repo
  exec { 'install-collection':
    command => "wget https://apt.puppetlabs.com/puppetlabs-release-pc1-${puppet_collections}.deb;dpkg -i puppetlabs-release-pc1-${$puppet_collections}.deb",
    user    => 'root',
    path    => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
    creates => '/tmp/puppetlabs-release-pc1-jessie.deb',
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
    server_version              => '2.7.2-1puppetlabs1',
    server_puppetserver_version => '2.7.2',
    server_jvm_min_heap_size    => '2048m',
    server_jvm_max_heap_size    => '4096m',
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