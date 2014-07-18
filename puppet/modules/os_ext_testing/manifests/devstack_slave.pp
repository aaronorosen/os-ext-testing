# A Jenkins slave that will execute jobs that use devstack
# to set up a full OpenStack environment for test runs.

class os_ext_testing::devstack_slave (
  $bare = true,
  $certname = $::fqdn,
  $ssh_key = '',
  $python3 = false,
  $include_pypy = false,
) {
  include os_ext_testing::base
  include openstack_project::tmpcleanup
  include openstack_project
  class { 'jenkins::slave':
    bare         => $bare,
    ssh_key      => $ssh_key,
    python3      => $python3,
    include_pypy => $include_pypy,
  }
  include devstack_host

  file { '/home/jenkins/cache/':
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'jenkins',
    require => User['jenkins'],
  }
  file { '/home/jenkins/cache/files/':
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'jenkins',
    require => file['/home/jenkins/cache/'],
  }

  file { '/srv/static/logs/robots.txt':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    source  => 'puppet:///modules/openstack_project/disallow_robots.txt',
    require => File['/srv/static/logs'],
  }

}
