#!/usr/bin/env bash

export PYTHONUNBUFFERED=1
export ANSIBLE_FORCE_COLOR=1

#
# Prepares the box for packaging
# Runs as part of the basebox provisioning. Can be manually invoked via
#
#    vagrant ssh
#    cd /vagrant/scripts
#    ./minimize-box.sh
#

printf "*** Clear apt cache ***\n"

sudo apt-get clean -y
sudo apt-get autoclean -y

printf "*** Zero out drive ***\n"

sudo dd if=/dev/zero | pv | sudo dd of=/EMPTY bs=1M
sudo rm -f /EMPTY

printf "*** Clear History ***\n"
cat /dev/null > ~/.bash_history && history -c && exit
