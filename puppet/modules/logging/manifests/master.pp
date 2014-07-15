# A log slave that will store output logs for tests run by Jenkins.
# This will provide a persistent location where all logs from the
# last 30 days can be accessed.

class logging::master($domain = 'mydomain.com',
                      $jenkins_ssh_key = $openstack_project::jenkins_ssh_key) {

  class { 'openstack_project::server':
    iptables_public_tcp_ports => [22, 80, 443],
    sysadmins                 => $sysadmins,
  }

  include openstack_project
  class { 'jenkins::jenkinsuser':
    ssh_key => $jenkins_ssh_key,
  }

  include apache
  include apache::mod::wsgi

  a2mod { 'rewrite':
    ensure => present,
  }
  a2mod { 'proxy':
    ensure => present,
  }
  a2mod { 'proxy_http':
    ensure => present,
  }

  file { '/srv/static':
    ensure => directory,
  }

  apache::vhost { "logs.$domain":
    port     => 80,
    priority => '50',
    docroot  => '/srv/static/logs',
    require  => File['/srv/static/logs'],
    template => 'openstack_project/logs.vhost.erb',
  }

  apache::vhost { "logs-dev.$domain":
    port     => 80,
    priority => '51',
    docroot  => '/srv/static/logs',
    require  => File['/srv/static/logs'],
    template => 'openstack_project/logs-dev.vhost.erb',
  }

  file { '/srv/static/logs':
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'jenkins',
    require => User['jenkins'],
  }

  file { '/srv/static/logs/robots.txt':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    source  => 'puppet:///modules/openstack_project/disallow_robots.txt',
    require => File['/srv/static/logs'],
  }

  file { '/srv/static/logs/help':
    ensure  => directory,
    recurse => true,
    purge   => true,
    force   => true,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    source  => 'puppet:///modules/openstack_project/logs/help',
    require => File['/srv/static/logs'],
  }

  file { '/usr/local/sbin/log_archive_maintenance.sh':
    ensure => present,
    owner  => 'root',
    group  => 'root',
    mode   => '0744',
    source => 'puppet:///modules/openstack_project/log_archive_maintenance.sh',
  }

  cron { 'gziprmlogs':
    user        => 'root',
    minute      => '0',
    hour        => '7',
    weekday     => '6',
    command     => 'bash /usr/local/sbin/log_archive_maintenance.sh',
    environment => 'PATH=/usr/bin:/bin:/usr/sbin:/sbin',
    require     => File['/usr/local/sbin/log_archive_maintenance.sh'],
  }
}
