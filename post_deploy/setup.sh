#!/bin/bash

# Script to run on a freshly launched Ubuntu DSVM, to
#  * Turn off auto updates
#  * Update the OS
#  * Install additionally required system packages
#  * Setup and configure disk quotas
#  * Setup quotas to survive reboot
#  * Install JupyterHub systemdspawner 
#  * Make changes to the JupyterHub configuration and restart the hub
#  * Create user accounts for users to use the hub on the DSVM
#    Note: users and their passwords are read from file
#               with following format (one user per line):
#               <username>|<password>

user_file="users.txt"
pip='/data/anaconda/envs/py35/bin/pip'

err_and_exit() {
  echo "ERROR: $1"
  exit 1
}

create_user_accounts_and_set_quotas() {
  echo "-------- Creating user accounts --------"
  user_file=$1
  if [ ! -f "${user_file}" ]; then
    err_and_exit "user file '${user_file}' doesn't exist"
  fi
  while read line; do
    user=$(echo ${line} | cut -d\| -f1 | xargs)
    pass=$(echo ${line} | cut -d\| -f2 | xargs)
    if [ -z "${user}" ]; then
      err_and_exit "username must not be empty"
    fi
    if [ -z "${pass}" ]; then
      err_and_exit "password must not be empty"
    fi
    echo "---- Creating account ${user}"
    useradd ${user}
    mkdir -p /home/${user}
    chown -R ${user}:${user} /home/${user}    # set ownership
    chmod -R 700 /home/${user}         # set permissions
    echo "${user}:${pass}" | chpasswd  # set password
    chsh -s /usr/sbin/nologin ${user}  # disable ssh login (notebook server spawning still works fine)
    quotatool -u ${user} -b -q 2G -l 2G /
    quotatool -u ${user} -b -q 2G -l 2G /data
  done < ${user_file}
}

edit_jupyterhub_config() {
  config="/etc/jupyterhub/jupyterhub_config.py"
  cpu_limit='1.0'
  mem_limit='2G'
 
  echo "-------- Making changes to JupyterHub configuration in ${config} --------"
  sed -i "s/c.Spawner.notebook_dir = '~\/notebooks'/c.Spawner.notebook_dir = '~'/g" ${config}

  echo "" >> ${config}
  echo "# Modifications for UoA" >> ${config}
  echo "c.JupyterHub.spawner_class = 'systemdspawner.SystemdSpawner'" >> ${config}
  echo "c.SystemdSpawner.disable_user_sudo = True" >> ${config}
  echo "c.SystemdSpawner.default_shell = '/bin/bash'" >> ${config}
  echo "c.SystemdSpawner.user_workingdir = '/home/{USERNAME}'" >> ${config}
  echo "c.SystemdSpawner.cpu_limit = ${cpu_limit}" >> ${config}
  echo "c.SystemdSpawner.mem_limit = '${mem_limit}'" >> ${config}
  echo "c.SystemdSpawner.isolate_tmp = True" >> ${config}
  echo "c.Authenticator.delete_invalid_users = True" >> ${config}
}

restart_jupyterhub() {
  echo "-------- Restarting JupyterHub --------"
  systemctl restart jupyterhub

}

install_system_packages() {
  echo "-------- Installing system packages --------"
  packages="sqlite3 quota quotatool linux-image-generic linux-headers-generic linux-modules-extra-$(uname -r)"
  for p in ${packages}; do
    echo "---- Installing package $p"
    apt-get install -y ${package}
  done
}

install_systemd_spawner() {
  echo "-------- Installing JupyterHub systemd spawner --------"
  ${pip} install --upgrade pip
  ${pip} install jupyterhub-systemdspawner
}

setup_quota_system() {
  echo "-------- Setting up quota system --------"
  modprobe quota_v1 quota_v2 > /dev/null
  lsmod | grep quota > /dev/null 2> /dev/null
  if [ $? -eq 0 ]; then
    for module in "quota_v1" "quota_v2"; do
      cat /etc/modules | grep ${module} > /dev/null
      if [ ! $? -eq 0 ]; then
        echo ${module} >> /etc/modules
      fi
    done
  else
    err_and_exit "quota module not loaded"
  fi
  echo "---- Remounting file systems with quota support --------"
  mount -o remount,usrquota /
  mount -o remount,usrquota /data
  #TODO: make this persistent
  echo "---- Turning quota off"
  quotaoff -pa
  for partition in "/" "/data"; do
    echo "---- Running quotacheck and turning quota on on partition ${partition} "
    quotacheck -cum ${partition}
    quotaon ${partition}
  done
}

configure_quotas_for_reboot() {
    f='/etc/rc.local'
    sed -i 's/exit 0//g' $f
    echo 'modprobe quota_v1 quota_v2' >> $f
    for partition in "/" "/data"; do
      echo "mount -o remount,usrquota ${partition}" >> $f
      echo "quotaon ${partition}" >> $f
    done
    echo 'exit 0' >> $f
}

turn_auto_updates_off() {
  echo "-------- Turning auto updates off --------"
  sed -i 's/APT::Periodic::Update-Package-Lists "1"/APT::Periodic::Update-Package-Lists "0"/g' /etc/apt/apt.conf.d/10periodic
}

update_system() {
  echo "-------- Updating and upgrading the system --------"
  apt-get update
  apt-get upgrade -y --force-yes -qq
}

# main


turn_auto_updates_off
update_system
install_system_packages
setup_quota_system
configure_quotas_for_reboot
install_systemd_spawner
edit_jupyterhub_config
restart_jupyterhub
create_user_accounts_and_set_quotas ${user_file}

