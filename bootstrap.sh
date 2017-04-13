#!/usr/bin/env bash
export PYTHONUNBUFFERED=1
export ANSIBLE_FORCE_COLOR=1

VAGRANT_DIRECT="vagrant-guest-direct"
VAGRANT_PROXY="vagrant-guest-proxy"

PROVISIONING_DIR="provisioning"

INVENTORY_FILE="${VAGRANT_DIRECT}"
LIMIT="${VAGRANT_DIRECT}"                          # which ansible group to run

USE_PROXY=false
ANSIBLE_TAGS=""
MAIN_PLAYBOOK="main.yml"

ANSIBLE_EXTRA_VARS=""

USE_VAGRANT_PROXYCONF_PLUGIN=true                  # TODO proxy is configured using the vagrant-proxyconf plugin
                                                   # for Ubuntu 16.04 we can not yet use the plugin, so we must set
                                                   # the proxy ourselves for the first phase of provisioning

while getopts "p:t:m:i:l:e:v:" opt; do
    case "$opt" in
        p)  USE_PROXY=$OPTARG
            ;;
        t)  ANSIBLE_TAGS=$OPTARG
            ;;
        m)  MAIN_PLAYBOOK=$OPTARG
            ;;
        i)  INVENTORY_FILE=$OPTARG
            ;;
        l)  LIMIT=$OPTARG
            ;;
        e)  ANSIBLE_EXTRA_VARS=$OPTARG
            ;;
        v)  USE_VAGRANT_PROXYCONF_PLUGIN=$OPTARG
            ;;
    esac
done

# initialize the inventory and the limit
if [[ "${USE_PROXY}" == "true" ]]; then
  INVENTORY_FILE="${VAGRANT_PROXY}"
else
  INVENTORY_FILE="${VAGRANT_DIRECT}"
fi


# build ansible options
ANSIBLE_OPTS=()
ANSIBLE_OPTS+=( "${MAIN_PLAYBOOK}" )
ANSIBLE_OPTS+=( "--connection=local" )
ANSIBLE_OPTS+=( "-vv" )
ANSIBLE_OPTS+=( "--inventory=/tmp/${INVENTORY_FILE}" )
# ANSIBLE_OPTS+=( "-l ${LIMIT}" )
ANSIBLE_OPTS+=( "--extra-vars=${ANSIBLE_EXTRA_VARS}" )
if [[ ! -z "${ANSIBLE_TAGS}" ]]; then
    ANSIBLE_OPTS+=( "--tags=${ANSIBLE_TAGS}" )
fi

###########################################
# setup inventory for vagrant guests
# directory is mirrored on guest
cd /vagrant/$PROVISIONING_DIR
# fix permissions on ansible logging dir
mkdir -p log
sudo find log -type d -exec chmod 777 {} \;

cp "${INVENTORY_FILE}" /tmp
chmod -X "/tmp/${INVENTORY_FILE}"

echo "Inventory file : ${INVENTORY_FILE}"
echo "Using vagrant-proxyconf : $USE_VAGRANT_PROXYCONF_PLUGIN"
echo "Ansible Playbook Run Parameters : ${ANSIBLE_OPTS[@]}"

# TODO Hack for Ubuntu 16.04 until the vagrant-proxyconf works again
if [[ "$USE_VAGRANT_PROXYCONF_PLUGIN" == "false" ]]; then

   echo "Set proxy values"
   export http_proxy="http://proxy.example.com:800"
   export https_proxy="http://proxy.example.com:800"
   export no_proxy="localhost,127.0.0.1,.example.com"

fi


if [ $(dpkg-query -W -f='${Status}' ansible 2>/dev/null | grep -c "ok installed") -eq 0 ];
then

    export DEBIAN_FRONTEND=noninteractive

    echo "Add APT repositories"
    sudo -E apt-get install -qq software-properties-common &> /dev/null || exit 1

    sudo -E apt-add-repository ppa:ansible/ansible &> /dev/null || exit 1

    echo "Run APT update"
    sudo -E apt-get update -qq

    echo "Installing Ansible"
    sudo -E apt-get install -qq ansible &> /dev/null || exit 1
    echo "Ansible installed"
fi

# invoke ansible playbook with options
ansible-playbook "${ANSIBLE_OPTS[@]}"
