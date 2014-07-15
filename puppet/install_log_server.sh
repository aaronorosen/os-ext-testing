#! /usr/bin/env bash

# Sets up a log server for Jenkins to save test results to.

set -e

THIS_DIR=`pwd`

OSEXT_PATH=$THIS_DIR/os-ext-testing
OSEXT_REPO=https://github.com/rasselin/os-ext-testing
PUPPET_MODULE_PATH="--modulepath=$OSEXT_PATH/puppet/modules:/root/config/modules:/etc/puppet/modules"

# Install Puppet and the OpenStack Infra Config source tree
if [[ ! -e install_puppet.sh ]]; then
  wget https://git.openstack.org/cgit/openstack-infra/config/plain/install_puppet.sh
  sudo bash -xe install_puppet.sh
  sudo git clone https://review.openstack.org/p/openstack-infra/config.git \
    /root/config
  sudo /bin/bash /root/config/install_modules.sh
fi

# Clone or pull the the os-ext-testing repository
if [[ ! -d $OSEXT_PATH ]]; then
    echo "Cloning os-ext-testing repo..."
    git clone $OSEXT_REPO $OSEXT_PATH
fi

if [[ "$PULL_LATEST_OSEXT_REPO" == "1" ]]; then
    echo "Pulling latest os-ext-testing repo master..."
    cd $OSEXT_PATH; git checkout master && sudo git pull; cd $THIS_DIR
fi

JENKINS_SSH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQCZBfq9HkS9urOg2lRkv+9B3tKDLu9h3QRd43aoMXQLXmivurnGEeVf1mptpWGeMB6E89XC/+xsMM3MxAlTQAuaTEhQ0aZjYpdawToYaj92BvoQRNShvQOOTIeehcZwJzudXu1WLXlv1+0gJIwPswkVqfnn5ptXePh3qhb2jFaZUQ=="

CLASS_ARGS="domain => 'csim.hp.com', "
CLASS_ARGS="$CLASS_ARGS jenkins_ssh_key => '$JENKINS_SSH_KEY', "

sudo puppet apply --verbose $PUPPET_MODULE_PATH -e "class {'logging::master': $CLASS_ARGS }"