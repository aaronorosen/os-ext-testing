#! /usr/bin/env bash

# Sets up a master Jenkins server and associated machinery like
# Zuul, JJB, Gearman, etc.

set -e

THIS_DIR=`pwd`

DATA_REPO_INFO_FILE=$THIS_DIR/.data_repo_info
DATA_PATH=$THIS_DIR/os-ext-testing-data
OSEXT_PATH=$THIS_DIR/os-ext-testing
OSEXT_REPO=https://github.com/rasselin/os-ext-testing
PUPPET_MODULE_PATH="--modulepath=$OSEXT_PATH/puppet/modules:/root/config/modules:/etc/puppet/modules"

# Install Puppet and the OpenStack Infra Config source tree
# TODO(Ramy) Make sure sudo has http proxy settings...
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

if [[ ! -e $DATA_PATH ]]; then
    echo "Enter the URI for the location of your config data repository. Example: https://github.com/rasselin/os-ext-testing-data"
    read data_repo_uri
    if [[ "$data_repo_uri" == "" ]]; then
        echo "Data repository is required to proceed. Exiting."
        exit 1
    fi
    git clone $data_repo_uri $DATA_PATH
fi

if [[ "$PULL_LATEST_DATA_REPO" == "1" ]]; then
    echo "Pulling latest data repo master."
    cd $DATA_PATH; git checkout master && git pull; cd $THIS_DIR;
fi

# Pulling in variables from data repository
. $DATA_PATH/vars.sh

# Validate that the upstream gerrit user and key are present in the data
# repository
if [[ -z $UPSTREAM_GERRIT_USER ]]; then
    echo "Expected to find UPSTREAM_GERRIT_USER in $DATA_PATH/vars.sh. Please correct. Exiting."
    exit 1
else
    echo "Using upstream Gerrit user: $UPSTREAM_GERRIT_USER"
fi

if [[ ! -e "$DATA_PATH/$UPSTREAM_GERRIT_SSH_KEY_PATH" ]]; then
    echo "Expected to find $UPSTREAM_GERRIT_SSH_KEY_PATH in $DATA_PATH. Please correct. Exiting."
    exit 1
fi
export UPSTREAM_GERRIT_SSH_PRIVATE_KEY_CONTENTS=`cat "$DATA_PATH/$UPSTREAM_GERRIT_SSH_KEY_PATH"`

# Validate there is a Jenkins SSH key pair in the data repository
if [[ -z $JENKINS_SSH_KEY_PATH ]]; then
    echo "Expected to find JENKINS_SSH_KEY_PATH in $DATA_PATH/vars.sh. Please correct. Exiting."
    exit 1
elif [[ ! -e "$DATA_PATH/$JENKINS_SSH_KEY_PATH" ]]; then
    echo "Expected to find Jenkins SSH key pair at $DATA_PATH/$JENKINS_SSH_KEY_PATH, but wasn't found. Please correct. Exiting."
    exit 1
else
    echo "Using Jenkins SSH key path: $DATA_PATH/$JENKINS_SSH_KEY_PATH"
    JENKINS_SSH_PRIVATE_KEY_CONTENTS=`sudo cat $DATA_PATH/$JENKINS_SSH_KEY_PATH`
    JENKINS_SSH_PUBLIC_KEY_CONTENTS=`sudo cat $DATA_PATH/$JENKINS_SSH_KEY_PATH.pub`
fi

PUBLISH_HOST=${PUBLISH_HOST:-localhost}

# Create a self-signed SSL certificate for use in Apache
APACHE_SSL_ROOT_DIR=$THIS_DIR/tmp/apache/ssl
if [[ ! -e $APACHE_SSL_ROOT_DIR/new.ssl.csr ]]; then
    echo "Creating self-signed SSL certificate for Apache"
    mkdir -p $APACHE_SSL_ROOT_DIR
    cd $APACHE_SSL_ROOT_DIR
    echo '
[ req ]
default_bits            = 2048
default_keyfile         = new.key.pem
default_md              = default
prompt                  = no
distinguished_name      = distinguished_name

[ distinguished_name ]
countryName             = US
stateOrProvinceName     = CA
localityName            = Sunnyvale
organizationName        = OpenStack
organizationalUnitName  = OpenStack
commonName              = localhost
emailAddress            = openstack@openstack.org
' > ssl_req.conf
    # Create the certificate signing request
    openssl req -new -config ssl_req.conf -nodes > new.ssl.csr
    # Generate the certificate from the CSR
    openssl rsa -in new.key.pem -out new.cert.key
    openssl x509 -in new.ssl.csr -out new.cert.cert -req -signkey new.cert.key -days 3650
    cd $THIS_DIR
fi
APACHE_SSL_CERT_FILE=`cat $APACHE_SSL_ROOT_DIR/new.cert.cert`
APACHE_SSL_KEY_FILE=`cat $APACHE_SSL_ROOT_DIR/new.cert.key`

if [[ -z $UPSTREAM_GERRIT_SERVER ]]; then
    UPSTREAM_GERRIT_SERVER="review.openstack.org"
fi

CLASS_ARGS="jenkins_ssh_public_key => '$JENKINS_SSH_PUBLIC_KEY_CONTENTS', jenkins_ssh_private_key => '$JENKINS_SSH_PRIVATE_KEY_CONTENTS', "
CLASS_ARGS="$CLASS_ARGS ssl_cert_file_contents => '$APACHE_SSL_CERT_FILE', ssl_key_file_contents => '$APACHE_SSL_KEY_FILE', "
CLASS_ARGS="$CLASS_ARGS upstream_gerrit_server => '$UPSTREAM_GERRIT_SERVER', "
CLASS_ARGS="$CLASS_ARGS upstream_gerrit_user => '$UPSTREAM_GERRIT_USER', "
CLASS_ARGS="$CLASS_ARGS upstream_gerrit_ssh_private_key => '$UPSTREAM_GERRIT_SSH_PRIVATE_KEY_CONTENTS', "
CLASS_ARGS="$CLASS_ARGS upstream_gerrit_ssh_host_key => '$UPSTREAM_GERRIT_SSH_HOST_KEY', "
if [[ -n $UPSTREAM_GERRIT_BASEURL ]]; then
    CLASS_ARGS="$CLASS_ARGS upstream_gerrit_baseurl => '$UPSTREAM_GERRIT_BASEURL', "
fi
CLASS_ARGS="$CLASS_ARGS git_email => '$GIT_EMAIL', git_name => '$GIT_NAME', "
CLASS_ARGS="$CLASS_ARGS publish_host => '$PUBLISH_HOST', "
CLASS_ARGS="$CLASS_ARGS data_repo_dir => '$DATA_PATH', "
if [[ -n $URL_PATTERN ]]; then
    CLASS_ARGS="$CLASS_ARGS url_pattern => '$URL_PATTERN', "
fi
CLASS_ARGS="$CLASS_ARGS mysql_root_password => '$MYSQL_ROOT_PASSWORD', "
CLASS_ARGS="$CLASS_ARGS mysql_password => '$MYSQL_PASSWORD', "
CLASS_ARGS="$CLASS_ARGS local_username => '$LOCAL_USERNAME', "
CLASS_ARGS="$CLASS_ARGS local_password => '$LOCAL_PASSWORD', "
CLASS_ARGS="$CLASS_ARGS local_01_ip => '$LOCAL_01_IP', "
CLASS_ARGS="$CLASS_ARGS jenkins_api_user => '$JENKINS_API_USER', "
CLASS_ARGS="$CLASS_ARGS jenkins_api_key => '$JENKINS_API_KEY', "
CLASS_ARGS="$CLASS_ARGS jenkins_credentials_id => '$JENKINS_CREDENTIALS_ID', "
CLASS_ARGS="$CLASS_ARGS jenkins_ssh_public_key_no_whitespace => '$JENKINS_SSH_PUBLIC_KEY_NO_WHITESPACE', "
CLASS_ARGS="$CLASS_ARGS http_proxy => '$HTTP_PROXY', "
CLASS_ARGS="$CLASS_ARGS https_proxy => '$HTTPS_PROXY', "
CLASS_ARGS="$CLASS_ARGS no_proxy => '$NO_PROXY', "

# Doing this here because ran into one problem after another trying
# to do this in Puppet... which won't let me execute Ruby code in
# a manifest and doesn't allow you to "merge" the contents of two
# directory sources in the file resource. :(
sudo mkdir -p /etc/jenkins_jobs/config
sudo cp -r $DATA_PATH/etc/jenkins_jobs/config/* /etc/jenkins_jobs/config/

sudo puppet apply --verbose $PUPPET_MODULE_PATH -e "class {'os_ext_testing::master': $CLASS_ARGS }"

#Not sure why nodepool private key is not getting set in the puppet scripts
sudo cp  $DATA_PATH/$JENKINS_SSH_KEY_PATH /home/nodepool/.ssh/id_rsa
