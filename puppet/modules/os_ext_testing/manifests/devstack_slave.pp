# A Jenkins slave that will execute jobs that use devstack
# to set up a full OpenStack environment for test runs.
# Ref: # == Class: openstack_project::slave
class os_ext_testing::devstack_slave (
  $thin = false,
  $certname = $::fqdn,
  $ssh_key = '',
  $sysadmins = [],
  $python3 = false,
  $include_pypy = false,
) {
  include os_ext_testing::base
  #TODO: Is including this an issue?
  #include devstack_host
  include openstack_project
  include openstack_project::automatic_upgrades
  include openstack_project::tmpcleanup

  #class { 'openstack_project::server':
  #  iptables_public_tcp_ports => [],
  #  certname                  => $certname,
  #  sysadmins                 => $sysadmins,
  #}

  class { 'jenkins::slave':
    ssh_key      => $ssh_key,
    python3      => $python3,
  }

  include jenkins::cgroups
  include ulimit
  ulimit::conf { 'limit_jenkins_procs':
    limit_domain => 'jenkins',
    limit_type   => 'hard',
    limit_item   => 'nproc',
    limit_value  => '256'
  }

  class { 'openstack_project::slave_common':
    include_pypy => $include_pypy,
  }

  if (! $thin) {
    include openstack_project::thick_slave
  }

  #Not sure why this is not added by upstream
  #package { 'python-yaml':
  #  ensure => installed
  #}

  #TODO: Are these needed? They're not need in upstream's.
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

  file { '/etc/sudoers.d/50_jenkins_sudo':
      ensure => present,
      owner  => 'root',
      group  => 'root',
      mode   => '0440',
      source => 'puppet:///modules/os_ext_testing/sudoers/50_jenkins_sudo',
  }
}