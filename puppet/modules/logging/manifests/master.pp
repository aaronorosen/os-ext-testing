# A log slave that will store output logs for tests run by Jenkins.
# This will provide a persistent location where all logs from the
# last 30 days can be accessed.

class logging::master($user = '', $group = '') {
  include apache

  apache::vhost { 'logs.csim.com':
    port     => 80,
    priority => '50',
    docroot  => '/srv/static/logs',
    require  => File['/srv/static/logs'],
    template => 'logging/logs.vhost.erb',
  }

  file { '/srv/static':
    ensure => directory,
  }
  
  file { '/srv/static/logs':
    ensure  => directory,
    owner   => $user,
    group   => $group,
  }

  file { '/srv/static/logs/robots.txt':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    source  => 'puppet:///modules/logging/disallow_robots.txt',
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
    source  => 'puppet:///modules/logging/logs/help',
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
