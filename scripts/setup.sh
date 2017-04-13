#!/usr/bin/env bash

echo "=================================="
echo "     Setup Vagrant Enviroment     "
echo "=================================="

# VirtualBox versions
MIN_VBOX_VERSION="4.3.36"
MAX_VBOX_VERSION="5.0.30"

DEFAULT_VBOX_VERSION="5.0"
USE_UBUNTU_REPO="true"

# Vagrant versions
MIN_VAGRANT_VERSION="1.8.2"
DEFAULT_VAGRANT_VERSION="1.8.5"

PROX_ENV_ERROR="Environment Variable required but not defined in your ~./bashrc!"

: ${http_proxy:? $PROX_ENV_ERROR }
: ${https_proxy}:? $PROX_ENV_ERROR}
: ${no_proxy:? $PROX_ENV_ERROR}

# Usage: call with a prompt string or use a default
confirm () {
    read -r -p "${1:-Are you sure? [y/N]} " response
    case $response in
        [yY][eE][sS]|[yY])
            true
            ;;
        *)
            false
            ;;
    esac
}

# get semantic version. If two paramters supplied get the major version
get_semantic_version() {

    if [[ $# -eq 0 ]] ; then
        echo 'No version command specified'
        exit 1
    else

       local semantic_version=$($1 | sed -r 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/g')

       if [ -z "$2" ]; then

          echo "$semantic_version"

       else

         local version_arr=(${semantic_version//./ })
         local major_version=$(printf ".%s" "${version_arr[@]:0:2}")
         echo "${major_version[@]:1}"

      fi

    fi
}

# Usage: check_version MIN CURRENT MAX
check_version() {

    local first last values

    # current version matches on of the limits
    [[ $2 = "$1" || $2 = "$3" ]] && return 0

    values=$(printf '%s\n' "$@" | sort -V)
    first=$(head -n1 <<< "$values")
    last=$(tail -n1 <<< "$values")

    [[ $2 != "$first" && $2 != "$last" ]]
}

# Get the latest vagrant version by scrapping website
get_latest_vagrant_version() {

  # get version array
  local version_array=($(wget --quiet -O - https://releases.hashicorp.com/vagrant/ | grep -o '<a href="/vagrant.*>' | grep -oP '(?<=href=")[^"]*(?=")' | sed -E 's/(\/.*\/)(.*)\//\2/'))
  # printf '%s' "$version_array"
  # arr=($version_array)
  # echo "fdfd"
  # printf '%s\n' "$arr"
  # echo $version_array
  # IFS=' ' read -a STR_ARRAY <<< "${version_array[@]}"

  # echo $version_array
  # version_array=(`echo "${version_array}"`)
  # printf '%s\n' "${STR_ARRAY[@]}"

  if [ ! ${#version_array[@]} -eq 0 ]; then
      echo "${version_array[0]}"
  else
      echo "$DEFAULT_VAGRANT_VERSION"
  fi

}

# usage setup_virtual_box MAJOR_VERSION USE_UBUNTU_REPO
function setup_virtual_box() {

  export DEBIAN_FRONTEND=noninteractive

  local v=${1-$DEFAULT_VBOX_VERSION}
  # echo $v

  local use_ubuntu_repo=${2-$USE_UBUNTU_REPO}
  # echo $use_ubuntu_repo

  if [ "$use_ubuntu_repo" = false ]; then

      echo "Install VirtualBox from Oracle repos"

      echo "deb http://download.virtualbox.org/virtualbox/debian trusty contrib" | sudo tee -a /etc/apt/sources.list.d/virtualbox.list
      wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add -
      wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -

      echo "Run APT update"
      sudo apt-get update -qq
      sudo apt-get -q -y install virtualbox-$v

  else

      echo "Install VirtualBox from Ubuntu repos"
      echo "Run APT update"
      sudo apt-get update -qq
      sudo apt-get -q -y install virtualbox

  fi

}


function setup_vagrant() {

  local v=${1-$DEFAULT_VAGRANT_VERSION}

  mkdir -p /tmp/vagrant_install && cd /tmp/vagrant_install
  wget "https://releases.hashicorp.com/vagrant/${v}/vagrant_${v}_x86_64.deb"
  sudo dpkg -i vagrant*.deb
  # rm -rf vagrant*.deb

}


# Setup Ansible ----------------------------------------------------------------
if [ $(dpkg-query -W -f='${Status}' ansible 2>/dev/null | grep -c "ok installed") -eq 0 ];
then

    export DEBIAN_FRONTEND=noninteractive

    echo "Add APT repositories"
    sudo apt-get install -qq software-properties-common &> /dev/null || exit 1

    sudo -E apt-add-repository ppa:ansible/ansible &> /dev/null || exit 1

    echo "Run APT update"
    sudo apt-get update -qq

    echo "Installing Ansible"
    sudo apt-get install -qq ansible &> /dev/null || exit 1
    echo "Ansible installed"

else

    echo "Ansible already installed. Moving on ..."

fi


# Setup VirtualBox -------------------------------------------------------------
if [ $(dpkg-query -W -f='${Status}' virtualbox* 2>/dev/null | grep -c "ok installed") -eq 0 ] ;
then

  setup_virtual_box

else

  # get version
  vbox_version=$(get_semantic_version "vboxmanage --version")
  major_version=$(get_semantic_version "vboxmanage --version" "true")

  if ! check_version $MIN_VBOX_VERSION $vbox_version $MAX_VBOX_VERSION; then

      echo "WARNING: VirtualBox version: $vbox_version is *NOT* in supported range [$MIN_VBOX_VERSION, $MAX_VBOX_VERSION]"

      if confirm "Would you like to update VirtualBox? [y/N]"; then
          setup_virtual_box "${DEFAULT_VBOX_VERSION}" "false"
      else
          echo "Aborting. Install VirtualBox manually!" && exit 1
      fi

  else
      echo "VirtualBox version : $vbox_version installed. Moving on ..."
  fi

fi


# Setup Vagrant ----------------------------------------------------------------
if [ $(dpkg-query -W -f='${Status}' vagrant 2>/dev/null | grep -c "ok installed") -eq 0 ] ;
then

  setup_vagrant

else

  # get version
  vagrant_version=$(get_semantic_version "vagrant --version")

  vagrant_latest_version=$(get_latest_vagrant_version)
  echo "Latest Vagrant version : " $vagrant_latest_version

  # get latest version
  if ! check_version $MIN_VAGRANT_VERSION $vagrant_version $vagrant_latest_version; then

      echo "WARNING: Vagrant version: $vagrant_version is *NOT* in supported range [$MIN_VAGRANT_VERSION, $vagrant_latest_version]"

      if confirm "Would you like to update to the latest Vagrant? [y/N]"; then
          setup_vagrant "$vagrant_latest_version"
      else
          echo "Aborting. Install Vagrant manually!" && exit 1
      fi

  else

      echo "Vagrant $vagrant_version already installed. Moving on ..."
  fi

fi

printf "\nFinished.\n"
